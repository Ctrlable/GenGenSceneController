/*
 * ZwInt - Z-Wave data monitor/interceptior for Vera
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/ip.h>
#include <poll.h>
#include <pthread.h>
#include <regex.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/timeb.h>
#include <sys/types.h>
#include <time.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <luaconf.h>

#define VERSION 1.05

#ifndef DEBUG
#define DEBUG 0
#endif

#if DEBUG
/* Timestamp compatible with LuaUPnP.log format */
static void timestamp() {
    struct timeb calendar;
	struct tm b;
	ftime(&calendar);
	localtime_r(&calendar.time, &b);
	fprintf(stderr, "77      %02d/%02d/%02d %d:%02d:%02d.%03d    ", b.tm_mon, b.tm_mday, b.tm_year%100, b.tm_hour, b.tm_min, b.tm_sec, calendar.millitm); 
}
#define DBG(str, ...) timestamp(); fprintf(stderr, str "\n", ##__VA_ARGS__)
#else
#define DBG(str, ...)
#endif

/*
 * A circular doubly linked list of monitor structures. 
 * The first entry in the list is monitors
 * The last entry is &dummyMonitor. 
 * dummyMonitor.next == monitors
 * monitors->prev == &dummyMonitor
 * The list is empty if monitors == &dummyMonitor
 */
typedef struct monitor {
	struct monitor *next;
	struct monitor *prev;
	int device_num;
	char *key;
	char intercept;			/* 1 if intercept, 0 if monitor */
	char oneshot;			/* 0 if not oneshot */
	char has_arm_pattern;	/* 1 if arm_pattern is valid */
	char armed;				/* 1 if intercept and arm_pattern has been matched */
	char forward;			/* 1 if response should be forwarded */
	regex_t arm_pattern;	/* Pattern to arm the intercept */
	regex_t pattern;
	char *response;		/* intercept only */
	long long int timeout;	/* milliseconds */
} monitor;

typedef struct httpRequest {
	struct httpRequest *next;
	int len;
	char request[];
} httpRequest;

#define MAX_ZWAVE_BUFF_SIZE 128
#define MAX_RESPONSE_PARTS 3
typedef struct zwave_state {
	unsigned char packet_buff[MAX_ZWAVE_BUFF_SIZE];
	int state;
	unsigned char checksum;
	unsigned char response_buff[MAX_ZWAVE_BUFF_SIZE];
	int response_zstate;
	int response_numParts;
	int response_partNum;
	unsigned char *response_zpos;
	unsigned char *response_lenpos;
	unsigned char *response_partpos[MAX_RESPONSE_PARTS+1]; 
	unsigned char *response_zstart;
	unsigned char response_checksum;
}zwave_state;

static monitor *monitors;
static monitor dummyMonitor;
static int inititalized;
static int registered;
static pthread_mutex_t mutex;
static int mon_fds[2];
static int original_commport_fd;
static int new_commport_fd;
static char commport_name[32];
static int http_fd = -1;
static int http_active = 0;
static int http_holdoff = 0;
static httpRequest *nextRequest, *lastRequest;
static pthread_t zwint_thread;
static zwave_state send_state, receive_state;

/*
 * now_fp_seconds is only used for the HTTP timestamp and is compatible with the
 * time returned in Lua by socket.gettime()
 */ 
static double now_fp_seconds() {
    struct timeval v;
    gettimeofday(&v, (struct timezone *) NULL);
    return v.tv_sec + v.tv_usec/1.0e6;
}

static long long int now() {
	struct timespec time;
	clock_gettime(CLOCK_MONOTONIC, &time);
	return time.tv_sec * 1000 + time.tv_nsec / 1000000;
}

static int zwint_error(lua_State *L, int err) {
	lua_pushnil(L);
    lua_pushinteger(L, err);
    lua_pushstring(L, strerror(err));
    return 3;
}

static int zwint_errorString(lua_State *L, int err, const char *errString) {
	lua_pushnil(L);
    lua_pushinteger(L, err);
    lua_pushstring(L, errString);
    return 3;
}

/* Thread errors cannot be passed back to the http server and must be dumped to /tmp/log.LuaUPnP 
 * (which should not be confused with /tmp/cmh/LuaUPnP.log) */
static void thread_error(char *label, int err) {
	fprintf(stderr, "zwint thread error: %s %d\n", label, err);
}

static void delete_from_monitor_list(monitor *m) {
	if (m == monitors) {
		monitors = m->next;
	}
	m->next->prev = m->prev;
	m->prev->next = m->next;
	DBG("delete %s -> %s -> %s -> %s",monitors->key,monitors->next->key,monitors->next->next->key,monitors->next->next->next->key);
	if (m->has_arm_pattern) {
		regfree(&m->arm_pattern);
	}
	regfree(&m->pattern);
	free(m);
}

static int repopen_http_fd(void) {
	if (http_fd < 0) {
		DBG("repopen_http_fd()");
	    http_fd = socket(AF_INET, SOCK_STREAM, 0);
	    if (http_fd < 0) {
			thread_error("repopen_http_fd", errno);
	        return -1;
		}
		struct sockaddr_in addr;
		bzero(&addr, sizeof(addr));
		addr.sin_family = AF_INET;
		addr.sin_port = htons(3480);
		addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
	    if (connect(http_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
			thread_error("Cannot connect to server", errno);
			close(http_fd);
			http_fd = -1;
		}
	}
	DBG("  http_fd()=%d", http_fd);
	return http_fd;
}

static void add_url_string(char *http, int *hlen, size_t http_size, char *string, int str_len) {
	int k;
	for (k = 0; k < str_len && *hlen < http_size-3; ++k) {
		char e = *string++;
		if (e == ' ') {
			http[(*hlen)++] = '%';
			http[(*hlen)++] = '2';
			http[(*hlen)++] = '0';
		} else {
			http[(*hlen)++] = e;
		}		
	}
} 

static int write_http_data(int hlen, char *http) {
	DBG("   Sending http: (%d bytes) %s",hlen, http);
	repopen_http_fd();
	int write_len = write(http_fd, http, hlen);
	DBG("   Wrote %d bytes to HTTP server", write_len);
	if(write_len < 1) {
		http_fd = -1;
		repopen_http_fd();
		write_len = write(http_fd, http, hlen);
		DBG("   retry: Wrote %d bytes to HTTP server", write_len);
	}
	return write_len;
}

static void DequeueHTTPData() {
	DBG("DequeueHTTPData: nextRequest@%p http_active=%d http_holdoff=%d", nextRequest, http_active, http_holdoff);   
	if (nextRequest && !http_active && !http_holdoff) {
		httpRequest *req = nextRequest; 
		if (write_http_data(req->len, req->request) > 0) {
			http_active = 1;
		}
		if (!(nextRequest = req->next)) {
			lastRequest = NULL;
	   	}
	   	free(req);	
	}
}

static void send_http(monitor *m, char *command, char *hexbuff, regmatch_t *matches, char *error_message) {
	char http[1000];
	if (m->key[0] == '*') {
		return;
	}
	int hlen = snprintf(http, sizeof(http), "GET /data_request?id=action&DeviceNum=%d&serviceId=urn:gengen_mcv-org:serviceId:ZWaveMonitor1&action=%s&key=%s&time=%f",
						m->device_num, command, m->key, now_fp_seconds());
	if (matches) {
		int j;
		int start = 1, end = 9;
		if (matches[1].rm_so < 0) {
			start = end = 0;
		}
		for (j = start; j <= end; ++j) {
			if (matches[j].rm_so >= 0) {
				hlen += snprintf(http+hlen, sizeof(http)-hlen, "&C%d=", j);
				add_url_string(http, &hlen, sizeof(http), hexbuff+matches[j].rm_so,  matches[j].rm_eo-matches[j].rm_so);
			}
		}
	}
	if (error_message) {
		hlen += snprintf(http+hlen, sizeof(http)-hlen, "&ErrorMessage=");
		add_url_string(http, &hlen, sizeof(http), error_message, strlen(error_message));
	}
	hlen += snprintf(http+hlen, sizeof(http)-hlen," HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n");
	DBG("send_http: http_active=%d http_holdoff=%d", http_active, http_holdoff);
	httpRequest *req = malloc(sizeof(httpRequest) + hlen + 1);
	if (req) {
		req->next = NULL;
		req->len = hlen;
		strncpy(req->request,http,hlen+1);
		if(lastRequest) {
			DBG("Queueing next http request@%p. lastRequest@%p http_active=%d http_holdoff=%d request=%s", req, lastRequest, http_active, http_holdoff, http); 
			lastRequest->next = req;
		} else {
			DBG("Queueing first and last http request@%p. http_active=%d http_holdoff=%d request=%s", req, http_active, http_holdoff, http); 
			nextRequest = req;
		}
		lastRequest = req;
		DequeueHTTPData();
	}
}

static void monitor_error(monitor *m, char *error_message) {
	send_http(m, "Error", NULL, NULL, error_message);
}

static int addZwaveResponseData(monitor *m, zwave_state *s, unsigned char *data, int len) {
	if (s->response_zpos-s->response_buff + len > MAX_ZWAVE_BUFF_SIZE) {
		monitor_error(m, "Response too long");
		return 1;
	}
	int i;
	for (i = 0; i < len; ++i) {
		unsigned char c = *data++;
		*(s->response_zpos++) = c;
		if (s->response_zstate == 0) {
			if (c == 1) { /* Start of frame */
				s->response_zstate = 1;
				s->response_zstart = s->response_zpos-1;
				s->response_checksum = 0xFF;
				s->response_lenpos = s->response_zpos;
			}	
		} else {
			s->response_zstate++;
			s->response_checksum ^= c;	
		}
	}
	return 0;
}


static void process_zwave(int input_fd, int output_fd, int send, zwave_state *s) {
	unsigned char raw_buff[1000];
	int raw_len;
	if ((raw_len = read(input_fd, raw_buff, sizeof(raw_buff))) > 0) {
		DBG("%s Got %d byte%s of data from fd %d", send ? "host->controller" : "controller->host", raw_len, raw_len==1?"":"s", input_fd);
		unsigned char *p = raw_buff;
		unsigned char *startp = raw_buff;
		unsigned char *endp = raw_buff + raw_len;
		while (p < endp) {
			unsigned char c = *p++;
			DBG("   s->state=%d c=0x%02X", s->state, c);
			if (send && s->response_partNum < s->response_numParts && s->state == 0) {
				if (c == 6) {	/* ack */
					startp = p;
					++s->response_partNum;
					DBG("   Swallowing ack %d of %d", s->response_partNum, s->response_numParts);
					if (s->response_partNum < s->response_numParts) {
						int rlen = s->response_partpos[s->response_partNum+1] - s->response_partpos[s->response_partNum];
						DBG("   Writing part %d of response: %d bytes", s->response_partNum+1, rlen);
						int result = write(input_fd, s->response_partpos[s->response_partNum], rlen);
						if (result < 0) {
							thread_error("Intercept write", errno);
						}
					} else {
						http_holdoff = 0;
						DequeueHTTPData();
					}
					continue;
				} else {
					s->response_numParts = 0;
				}
			}
			if (s->state == 0) {	/* Not locked onto packet yet */
				if (c == 1) {
					s->state = 1;
					s->packet_buff[0] = c;
					s->checksum = 0xff;
					if (p > startp+1) {
						write(output_fd, startp, p-1-startp);
						startp = p-1;
					}
				}
			} else if (s->state == 1) { /* packet length */
				if (c >= MAX_ZWAVE_BUFF_SIZE) { /* Impossible, too long */
					s->state = 0;
				} else {
					s->state = 2;
					s->packet_buff[1] = c;
					s->checksum ^= c;
				}
			} else {
				s->packet_buff[s->state] = c;
				s->checksum ^= c;
				int len = s->packet_buff[1] + 2;
				if (s->state == len - 1) { /* Checksum */
					DBG("   checksum=0x%02X", s->checksum);
					if (s->checksum == 0) { /* Good packet */
						int intercepted = 0;
						char hexbuff[MAX_ZWAVE_BUFF_SIZE * 3];
						char *h = hexbuff;
						static const char *hex = "0123456789ABCDEF";
						int i;
						for (i = 0; i < len; ++i) {
							if (i > 0) {
								*h++ = ' ';
							}
							*h++ = hex[s->packet_buff[i]>>4];
							*h++ = hex[s->packet_buff[i]&15];
						}
						*h++ = 0;
						DBG("   hexbuff=%s",hexbuff);
						monitor *m = monitors;
						while (m != &dummyMonitor) {
							if (m->intercept ^ send ^ m->armed) { /* armed ? intercept == send : intercept != send */
								regmatch_t matches[10];
								regex_t *regex = m->armed ? &m->pattern : &m->arm_pattern;
								DBG("   Trying monitor: %s", m->key);
								if (regexec(regex, hexbuff, 10, matches, 0) == 0) {
									DBG("   Monitor: %s passed", m->key);
									if (!m->armed) {
										m->armed = 1;
										DBG("   Monitor %s is now armed", m->key);
									} else {
										if(m->response) {
											const char *r = m->response;
											s->response_zpos = s->response_buff;
											s->response_numParts = 0;
											s->response_partNum = 0;
											s->response_partpos[0] = s->response_buff;
											s->response_zstate = 0;
											int rstate = 0;
											char c;
											int error = 0;
											unsigned char byte = 0;
											while ((c = *r++) && !error) {
												DBG("      %s c=%c rstate=%d byte=0x%02X", m->forward ? "forward" : "response", c, rstate, byte);
												int val = -1;
												if (c >= '0' && c <= '9' && rstate < 4) {
													val = c - '0';
												} else if (c >= 'a' && c <= 'f' && rstate <= 1) {
													val = c - 'a' + 10;
												} else if (c >= 'A' && c <= 'F' && rstate <= 1) {
													val = c - 'A' + 10;
												} else if (c == ' ' && rstate == 0) {
													continue;
												} else if (c == ' ' && rstate == 1) {
													rstate = 2;
												} else if (c == '\\' && rstate == 0) {
													rstate = 3;
													continue;
												} else if ((c == 'X' || c == 'x') && (rstate == 0 || rstate == 4)) {
													if (rstate == 0) {
														rstate = 4;
														continue;
													} else {
														rstate = 5;
													}
												} else {
													/* Syntax error */
													DBG("      Response syntax error");
													monitor_error(m, "Response syntax error");
													error = 1;
													break;
												}
												switch(rstate) {
													case 0: /* First hex digit */
														byte = val;
														rstate = 1;
														break;
													case 1: /* Second hex digit */
														byte = (byte << 4) + val;
														/* drop through */
													case 2: /* Single hex digit */
														error = addZwaveResponseData(m, s,&byte,1);
														rstate = 0;
														break;
													case 3: /* \1 - \9 replacement */
														if (matches[val].rm_so < 0) {
															monitor_error(m, "Unmatched replacement");
															error = 1;
														} else {
															error = addZwaveResponseData(m, s, &s->packet_buff[matches[val].rm_so/3], (2 + matches[val].rm_eo-matches[val].rm_so)/3);
														}
														rstate = 0;
														break;
													case 5: /* Checksum */
														if (s->response_zstate < 2) {
															/* monitor_error(m, "Bad Response checksum"); */
															error = 1;
														} else {
															int newLen = s->response_zstate-1;
															s->response_checksum ^= (newLen ^ *s->response_lenpos);
															*s->response_lenpos = newLen;
															if (addZwaveResponseData(m, s, &s->response_checksum, 1)) {
																error = 1;
															}
														}
														s->response_partpos[++s->response_numParts] = s->response_zpos;
														if (s->response_numParts > MAX_RESPONSE_PARTS) {
															error = 1;
														}															
														s->response_zstart = s->response_zpos;
														s->response_zstate = 0;
														rstate = 0;
														break; 
												} 
											}
											if (!error && rstate == 1) {
												error = addZwaveResponseData(m, s, &byte, 1);
											}
											if (!error) {
												if (s->response_partpos[s->response_numParts] < s->response_zpos && s->response_numParts < MAX_RESPONSE_PARTS) {
													s->response_partpos[++s->response_numParts] = s->response_zpos;
												}
												int rlen = s->response_partpos[1] - s->response_buff; 
												int result = write(m->forward ? output_fd : input_fd, s->response_buff, rlen);
												if (result < 0) {
													thread_error(m->forward ? "Forward write" : "Response write", errno);
												
												}
												s->response_partNum = 0;
												intercepted = 1;
											} else { /* error */
												break;
											}
										}
										if (send && s->response_numParts > 0) {
											/* Hold off sending the HTTP request until all reponses have been sent and acks received
											 * to avoid a deadlock race condition in LuaUPnP */
											http_holdoff = 1;
										}
										send_http(m, send?"Intercept":"Monitor", hexbuff, matches, NULL);
										if (m->has_arm_pattern) {
											DBG("   Monitor %s is now unarmed", m->key);
											m->armed = 0;
										}
										if (m->oneshot) {
											monitor *p = m->prev;
											DBG("   Deleting oneshot: %s", m->key);
											delete_from_monitor_list(m);
											m = p;
										}
										if (intercepted) {
											break;
										}
									} /* else !intercetp || armed */
								} /* if regex match */
							} /* if m->intercept == send */
							m = m->next;
						}
						if (!intercepted) {
							int result = write(output_fd, s->packet_buff, len);
							if (result < 0) {
								thread_error("Passthrough write", errno);
							}
							DBG("   Not intercepted. Pass through %d byte%s to fd %d. result=%d", len, len==1?"":"s", output_fd, result);
						} 
					} else {
						/* bad checksum. Pass the whole packet through */
						int result = write(output_fd, s->packet_buff, len);
						if (result < 0) {
							thread_error("Bad checkum write", errno);
						}
						DBG("   Bad checksum. Pass through %d byte%s to fd %d. result=%d", len, len==1?"":"s", output_fd, result);
					}
					s->state = 0;
					startp = p;
				} else {
					++s->state;
				}
			}
		}
		if (s->state == 0 && endp > startp) {
			int tlen = endp - startp;
			int result = write(output_fd, startp, tlen);
			if (result < 0) {
				thread_error("Tail write", errno);
			}
			DBG("   Writing %d trailing output byte%s to fd %d. Result=%d",tlen,tlen==1?"":"s", output_fd, result); 
		}
	}
}

static void *zwint_threadFunction(void *arg) {
	DBG("Start zwint thread");
	struct pollfd pollfds[3];
	pthread_mutex_lock(&mutex);
	while(1) {
		pollfds[0].fd = mon_fds[1];
		pollfds[1].fd = new_commport_fd;
		pollfds[2].fd = http_fd;
		int i;
		for (i = 0; i < 3; ++i) {
			pollfds[i].events = POLLIN;
			pollfds[i].revents = 0; 
		}
		int timeout_ms = -1;
		if (monitors->timeout) {
			timeout_ms = monitors->timeout - now(); 
			if (timeout_ms < 1) {
				timeout_ms = 1;
			}
		}
		DBG("Calling poll. timeout=%d", timeout_ms);
		pthread_mutex_unlock(&mutex);
		int result = poll(pollfds, 3, timeout_ms);
		DBG("Poll returned %d", result);
		pthread_mutex_lock(&mutex);
		if (registered <= 0) {
			close(mon_fds[1]);
			if (http_fd >= 0) {
				close(http_fd);
				http_fd = -1;
			}
			pthread_mutex_unlock(&mutex);
			return NULL;
		}
		long long int ms = now();
		while (monitors->timeout && monitors->timeout <= ms) {
			DBG("Timing out monitor with key: %s", monitors->key);
			send_http(monitors, "Timeout", NULL, NULL, NULL);
			delete_from_monitor_list(monitors);
		}
		if (result > 0) {
			if (pollfds[0].revents) {
				DBG("host_fd %d revents = %d", mon_fds[1], pollfds[0].revents);
				if (pollfds[0].revents & POLLIN) {
					process_zwave(mon_fds[1], new_commport_fd, 1, &send_state);
				} else {
					thread_error("intercept", pollfds[0].revents); 
				}
			}
			if (pollfds[1].revents) {
				DBG("controller_fd %d revents = %d", new_commport_fd, pollfds[1].revents);
				if (pollfds[1].revents & POLLIN) {
					process_zwave(new_commport_fd, mon_fds[1], 0, &receive_state);
				} else {
					thread_error("monitor", pollfds[0].revents); 
				} 
			}
			if (pollfds[2].revents != 0) {
				DBG("http_fd %d revents = %d", http_fd, pollfds[2].revents);
				if (pollfds[2].revents & POLLIN) {
					int first = 1;
					int len2;
					int total = 0;
					do {
						char buffer[1000];
					    len2 = read(http_fd,buffer,sizeof(buffer)-1);
						if (len2 > 0) {
							total += len2;
#if DEBUG
							buffer[len2] = 0;
							DBG("Received %d bytes (total %d bytes) from http server: %s", len2, total, buffer);
#endif
						}
						if (len2 == 0 && first) {
							DBG("http_fd closed");
							close(http_fd);
							http_fd = -1;
							break;
						}
						first = 0;
					} while (len2 > 0);
					if (http_fd >= 0) {
						DBG("Closing http_fd %d", http_fd);
						close(http_fd);
						http_fd = -1;
					}
					http_active = 0;
					DequeueHTTPData();
				} else {
					thread_error("output", pollfds[0].revents); 
				} 
			}
		}
	}
}

#if DEBUG
/*
 * zwint.instance()
 * Used to verify whether the module was loaded more than onece.
 * Returns: a unique instance number starting with 1.
 */
static int instance = 0;
static int zwint_instance(lua_State *L) {
	++instance;
	lua_pushinteger(L, instance);
	return 1;
}
#endif

/*
 * zwint.register(device_path)
 * Registers the device for Z-Wave interception messages.
 * device_path: Device which is monitoring Z-Wave data: typically "/dev/ttys0"
 * Returns: true if success 
 *          nil, errno, errString if error 
 */
static int zwint_register(lua_State *L) {
	size_t  device_path_len;
	const char *device_path = lua_tolstring(L, 1, &device_path_len);
	if (!device_path || device_path_len >= sizeof(commport_name)) {
        return luaL_argerror(L, 1, "Bad device_path");
	}
	pthread_mutex_lock(&mutex);
	if (registered) {
		if (strcmp(device_path, commport_name)) {
			pthread_mutex_unlock(&mutex);
        	return luaL_argerror(L, 1, "Device_path does not match already registered name");
		}
		++registered;
	} else {
		const char *prefix = "/proc/self/fd/";
		DIR *dir = opendir(prefix);
		if (!dir) {
			return zwint_error(L, errno);
		}
		original_commport_fd = -1;
		struct dirent *dirent;
		while ((dirent = readdir(dir))) {
			if(dirent->d_type == DT_LNK) {
				char path[256];
				char buff[256];
				snprintf(path, sizeof(path), "%s%s", prefix, dirent->d_name); 
				size_t size = readlink(path, buff, sizeof(buff)-1);
				if (size > 0) {
					buff[size] = 0;
					if (!strcmp(buff, device_path)) {
						char *endptr;
						int num = strtol(dirent->d_name, &endptr, 10);
						if (!*endptr) {
							original_commport_fd = num;
							DBG("original_commport_fd=%d",original_commport_fd);
							break;
						}
					} 
				}
			}
		}
		closedir(dir);
		if (original_commport_fd < 0) {
			pthread_mutex_unlock(&mutex);
        	return luaL_argerror(L, 1, "Device_path not found in open file list");
		}
		strcpy(commport_name, device_path);
		int result =  pthread_create(&zwint_thread, NULL, zwint_threadFunction, NULL); 
		if (result) {
			pthread_mutex_unlock(&mutex);
			return zwint_error(L, result);
		}
		/* No need to delete the thread if errors occur below. It will die on its own if registered == 0 */
		if (socketpair(AF_UNIX, SOCK_STREAM, 0, mon_fds)) {
			pthread_mutex_unlock(&mutex);
			return zwint_error(L, errno);
		}
		DBG("Created socket pair. fds %d and %d", mon_fds[0], mon_fds[1]);
		result = dup2(mon_fds[0], original_commport_fd);
		DBG("Dup2. old_fd=%d, new_fd=%d, result=%d", mon_fds[0], original_commport_fd, result);
		close(mon_fds[0]);
		DBG("Closing fd %d after dup2", mon_fds[0]);
		if (result < 0) {
			int err = errno;
			close(mon_fds[1]);
			pthread_mutex_unlock(&mutex);
			return zwint_error(L, err);
		}
		new_commport_fd = open(commport_name, O_RDWR);
		DBG("New commport fd=%d", new_commport_fd);
		if (new_commport_fd < 0) {
			/* We are in trouble since we cannot reopen the comm port. Clean up the best we can */ 
			int err = errno;
			close(mon_fds[1]);
			pthread_mutex_unlock(&mutex);
			return zwint_error(L, err);
		}
	}
	registered++;
	pthread_mutex_unlock(&mutex);
	lua_pushboolean(L, 1);
	return 1;	
}

/*
 * zwint.unregister(device_num <optional>)
 * Unregisters the device to no longer receive Z-Wave interception messages.
 * If device_num is an integer, then all active monitors and intercepts for that device number will be canceled
 * If device_num is missing or nil, then all active monitors and intercepts will be canceled.
 * Returns: true if success 
 *          nil, errno, errString if error 
 */
static int zwint_unregister(lua_State *L) {
	int dev_num = -1;
	if (lua_gettop(L) >= 1) {
		if (!lua_isnil(L, 1)) {
			if (!lua_isinteger(L, 1)) {
	        	return luaL_argerror(L, 1, "Device number not an integer");
			}
			dev_num = lua_tointeger(L, 1);
		}
	}
	pthread_mutex_lock(&mutex);
	if (registered <= 0) {
		pthread_mutex_unlock(&mutex);
		return zwint_errorString(L, registered, "Not registered");
	}
	if (--registered == 0) {
		dev_num = -1;
		if (dup2(new_commport_fd, original_commport_fd) < 0) {
			int result = errno;
			pthread_mutex_unlock(&mutex);
			return zwint_error(L, result);
		}
	}
	monitor *m = monitors;
	while (m != &dummyMonitor) {
	    monitor *n = m->next;
		if (dev_num < 0 || dev_num == m->device_num) {
			delete_from_monitor_list(m);
		}
		m = n;
	}
	pthread_mutex_unlock(&mutex);
	lua_pushboolean(L, 1);
	return 1;	
}

/*
 * Sort 0 (no timeout) after positive absolute times times in ms since the epoch
 */
static int compareTimeout(long long int t1, long long int t2) {
	return t1 ? (t2 ? t1 - t2 : -1) : (t2 ? 1 : 0);
}

/*
 * Common code for monitor and intercept 
 */
static int wwint_monitor_intercept(lua_State *L, int is_intercept) {
	if (!lua_isnumber (L, 1)) {
        return luaL_argerror(L, 1, "Device_num not a number");
	}
	int device_num = lua_tointeger(L, 1);
	size_t key_len;
	const char *key = lua_tolstring (L, 2, &key_len);
	if (!key) {
        return luaL_argerror(L, 2, "Key not a string");
	}
	size_t pattern_len;
	const char *pattern = lua_tolstring (L, 3, &pattern_len);
	if (!pattern) {
        return luaL_argerror(L, 3, "Pattern not a string");
	}
	int oneshot = lua_toboolean(L, 4);
	if (!lua_isnumber (L, 5)) {
        return luaL_argerror(L, 5, "timeout not a number");
	}
	int timeout = lua_tointeger(L, 5);
	size_t response_len;
	const char *response;
	const char *arm_pattern = "";
	size_t arm_pattern_len;
	int has_arm_pattern = 0;
	if (lua_gettop(L) >= 6 && !lua_isnil(L, 6)) {
		arm_pattern = lua_tolstring (L, 6, &arm_pattern_len);
		if (!pattern) {
	        return luaL_argerror(L, 6, "Arm_attern not a string or nil");
		}
		has_arm_pattern = 1;
	}
	if (lua_gettop(L) >= 7 && !lua_isnil(L, 7)) {
		response = lua_tolstring (L, 7, &response_len);
		if (!response) {
	        return luaL_argerror(L, 7, "Response not a string");
		}
	} else {
		response = "";
		response_len = 0;
	}
	int forward = 0;
	if (lua_gettop(L) >= 8) {
		if (lua_isboolean(L, 8)) {
			forward = lua_toboolean(L, 8);
		} else {
        	return luaL_argerror(L, 8, "Forward not boolean");
		}
	}

	int monitor_len =  sizeof(monitor) + strlen(key) + strlen(response) + 2;
	monitor *m = malloc(monitor_len);
	if (!m) {
		return zwint_error(L, errno);
	}

	int result = regcomp(&m->pattern, pattern, REG_EXTENDED | REG_ICASE);
	if (result) {
		char errbuff[300];
		regerror(result, &m->pattern, errbuff, sizeof(errbuff));
		free(m);
		return zwint_errorString(L, result, errbuff);   
	}
	if (has_arm_pattern) {
		result = regcomp(&m->arm_pattern, arm_pattern, REG_EXTENDED | REG_ICASE);
		if (result) {
			char errbuff[300];
			regerror(result, &m->arm_pattern, errbuff, sizeof(errbuff));
			regfree(&m->pattern);
			free(m);
			return zwint_errorString(L, result, errbuff);   
		}
	}
	m->device_num = device_num;
	char *p = (char *)m + sizeof(monitor);
	strcpy(p, key);
	m->key = p;
	p += strlen(p) + 1;
	m->intercept = is_intercept;
	m->oneshot = oneshot;
	m->has_arm_pattern = has_arm_pattern;
	m->armed = !has_arm_pattern;
	strcpy(p, response);
	m->response = response_len > 0 ? p : NULL;
	m->forward = forward;
	m->timeout = timeout ? now() + timeout : 0;
	DBG("Lua %s: key=%s arm_pattern=%s pattern=%s response=%s oneshot=%d timeout=%d forward=%d", m->intercept?"intercept":"monitor", m->key, arm_pattern, pattern, response, m->oneshot, timeout, forward);  
	pthread_mutex_lock(&mutex);
	/* Insert the monitor into the doubly linked circular list so that the
	 * entries with the soonest timeout comes first followed by any with no timeout
	 */
	monitor *m2 = monitors;
	while (compareTimeout(m->timeout, m2->timeout) > 0) {
		m2 = m2->next;
		if (m2 == &dummyMonitor) {
			break;
		}
	}
	m->prev = m2->prev;
	m->next = m2;
	m->prev->next = m;
	m2->prev = m;
	if (m2 == monitors) {
		monitors = m;
	}
	DBG("insert %s -> %s -> %s -> %s",monitors->key,monitors->next->key,monitors->next->next->key,monitors->next->next->next->key);
	pthread_mutex_unlock(&mutex);

	lua_pushboolean(L, 1);
	return 1;	
}

/*
 * zwint.monitor(device_num, key, pattern, oneshot, timeout, <arm_pattern>, <response>, <forward>)
 * Monitor for incoming Z-Wave data.
 * device_num: LuaUPnP Device number which is monitoring Z-Wave.
 * key: string - returned through the HTTP server when the monitor matches.
 *   If the key begins with '*' then HTTP response is suppressed.
 * pattern: string - Posix extended regular expression to match the hexified Z-Wave packet
 *   The packet will consist of space separated hex digit pairs always starting with 01 (SOF) and
 *   ending with the Z-Wave checksum
 * oneshot: Boolean - True if the monitor should automatically be canceled when the pattern is matched
 *   if oneshot is false and arm_pattern is not nil then the monitor will be unarmed once pattern is matched.
 * timeout: number - miliseconds before monitor times out. 0 for no timeout.
 *   timeout can occur whether armed or not.
 * arm_pattern: string <optional or nil> - ERegex for Z-Wave sent by LuaUPnP used to arm the monitor. 
 *   We expect the controller to send data matching pattern in response to data matching arm_pattern
 *   If data matching pattern is received without first sending arm_pattern, then it will be passed through.
 *   If arm_pattern is nil or missing, the monitor is always armed.
 * response: string <optional or nil> - Response expected by the controller in response to the received packet.
 *   If response is not specified, pass through the data to LuaUPnP but also send a monitor action to the HTTP server. 
 *   If response is specified, don't pass the data to LuaUPnP but send back the response expected by the controller.
 *      typically 06 (ACK)
 * forward: If present and true, the response is forwarded to the Z-Wave controller and 
 *   replaces the message from the device rather than being sent back to the device. In this way, it is possible
 *   to filter messages that the controller does not understand and which confuses it. 
 * Returns: true if success 
 *          nil, errno, errString if error 
 */
static int zwint_monitor(lua_State *L) {
	return wwint_monitor_intercept(L, 0);
}

/*
 * zwint.intercept(device_num, key, pattern, oneshot, timeout, <arm_pattern>, <response>)
 * Monitor for outgoing Z-Wave data. 
 * device_num: LuaUPnP Device number which is monitoring Z-Wave.
 * key: string - returned through the HTTP server when the monitor matches
 *   If the key begins with '*' then HTTP response is suppressed.
 * pattern: string - Posix extended regular expression to match the hexified Z-Wave packet
 * oneshot: Boolean - True if the monitor should automatically be canceled when the pattern is matched
 *   if oneshot is false and arm_pattern is not nil then the intercept will be unarmed once pattern is matched.
 * timeout: number - miliseconds before monitor times out. 0 for no timeout.
 *   timeout can occur whether armed or not.
 * arm_pattern: string <optional or nil> - ERegex for Received Z-Wave used to arm the intercept. 
 *   We expect the LuaUPnP engine to send data matching pattern in response to data matching arm_pattern
 *   If data matching pattern is sent without first receiving arm_pattern, the data will be passed through.
 *   If arm_pattern is nil or missing, the intercept is always armed.
 * response: string <optional or nil> - Response expected by LuaUPnP to the intercepted packet.
 *   If response is not specified, pass through the data to LuaUPnP but also send a monitor action to the HTTP server. 
 *   If response is specified, don't pass the data to LuaUPnP but send back the response expected by the controller.
 *   Response is in hex and may have \0 .. \9 captures from the intercepted pattern an
 *   Use XX to fill in the checksum 
 *   ZwInt will automatically remove and 06 (ACK) responses from the controller acknowledging the response.
 * forward: If present and true, the response is forwarded to the device and 
 *   replaces the message from the controller rather than being sent back to the controller. In this way, it is possible
 *   to filter messages from the controller that the device does not understand and which confuse it. 
 * Returns: true if success 
 *          nil, errno, errString if error 
 */
static int zwint_intercept(lua_State *L) {
	return wwint_monitor_intercept(L, 1);
}

/*
 * zwint.cancel(device_num, key)
 * Cancels an existing monitor or intercept with the given key
 * device_num: Device which was monitoring Z-Wave data and previously passed to zwave_register
 * key: string - same as passed to monitor or intercept
 * Returns: true if monitor was found and deleted
 *          false if monitor was not found (not necessarily an error) 
 *          nil, errno, errString if error 
 */
static int zwint_cancel(lua_State *L) {
	if (!lua_isnumber (L, 1)) {
        return luaL_argerror(L, 1, "Device_num not a number");
	}
	int device_num = lua_tointeger(L, 1);
	size_t key_len;
	const char *key = lua_tolstring (L, 2, &key_len);
	if (!key) {
        return luaL_argerror(L, 2, "Key not a string");
	}
	int found = 0;
	pthread_mutex_lock(&mutex);
	monitor *m = monitors;
	while (m != &dummyMonitor) {
		if (m->device_num == device_num && !strcmp(m->key, key)) {
			delete_from_monitor_list(m);
			found = 1;
			break;
		}
		m = m->next;
	}
	pthread_mutex_unlock(&mutex);
	lua_pushboolean(L, found);
	return 1;	
}

/* object table */
static const luaL_reg zwint_reg[] = {
#if DEBUG
	{"instance",    zwint_instance},
#endif
    {"register",    zwint_register},
	{"unregister",	zwint_unregister},
	{"monitor",     zwint_monitor},
    {"intercept",   zwint_intercept},
    {"cancel",      zwint_cancel},
    {NULL,          NULL}
};

/* entry point */
int luaopen_zwint(lua_State *L) {
DBG("Start luaopen_zwint");
	if (!inititalized) {
		int result = pthread_mutex_init(&mutex, NULL); 
		if (result) {
			return zwint_error(L, result);
		}
		inititalized = 1;
		monitors = dummyMonitor.next = dummyMonitor.prev = &dummyMonitor;
		dummyMonitor.key = "*Dummy*";
	}
#if LUA_VERSION_NUM < 502
	luaL_register(L, "zwint", zwint_reg);
#else
	luaL_newlib(L, zwint_reg);
#endif
	/* module version */
	lua_pushnumber(L, VERSION);
	lua_setfield(L, -2, "version");
	return 1;
}
