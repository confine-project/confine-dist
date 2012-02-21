/*
** broadcastflood.c 
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

#include <unistd.h>

 extern char *optarg;
 extern int optind;
 extern int optopt;
 extern int opterr;
 extern int optreset;


#define MAX_MSG_SIZE 64*1024-1024
#define MAX_HOSTNAME 1024
#define SERVERPORT 4950    // the port users will be connecting to


void syntax(const char* argv0) {
	fprintf(stderr,"UDP Broadcast flooder.\n");
	fprintf(stderr,"This program was written to send out UDP broadcasts in order to test wireless (Wi-Fi) drivers under the special condition that you can not expect an ARP answer because the Wi-Fi card is connected to an attenuator and a spectrum analyzer (and hence gets no network answer) while at the same time you want to meausre the actual txpower of the Wi-Fi signal coming out of the card.\nHence we send out broadcast packets\n\n");
	fprintf(stderr,"Copyright 2011 (C) by L. Aaron Kaplan <aaron@lo-res.org>, License GPLv3");
	fprintf(stderr,"\n\n");
	fprintf(stderr,"usage: %s [-n num_packets] [-m message] [-t destination_ip] [-i interface] [-s packet_length]\n", argv0);
	fprintf(stderr,"          -h ...............  this help screen\n");
	fprintf(stderr,"          -n N..............  send N packets, then quit\n");
	fprintf(stderr,"          -m M..............  send the text message M (default message 'FFFFF....') \n");
	fprintf(stderr,"          -t T..............  target T, send to this ip address or hostname (not you can specify broadcast addresses)\n");
	fprintf(stderr,"          -i I..............  send over interface I (default: eth0)\n");
	fprintf(stderr,"          -s S..............  send S many bytes per message\n");
	fprintf(stderr,"          -g ...............  generate a random packet (with S bytes)\n");

}


int main(int argc, char *argv[])
{
    int sockfd;
    struct sockaddr_in remote_addr; // connector's address information
    struct hostent *he;
    int numbytes = 0;
    int broadcast = 1;
	int limit = 10000;
	char ch;
	char interface[16] = "eth0";
	int bSetInterface = 0;
	char target[MAX_HOSTNAME] = "";
	int bSetTarget = 0;
	char message[MAX_MSG_SIZE] = "";
	int msg_bytes = 64;
	int i;
	char *ipstr = "255.255.255.255";
	struct in_addr ip;
	char generate=0;
	unsigned long total_bytes = 0;

	errno=0;
	ip.s_addr = 0;
	for (i=0;i<MAX_MSG_SIZE-1;i++) {
		message [i] = 'F';
	}
	message [MAX_MSG_SIZE-1]=0;
	
	if (argc ==1 ) {
		fprintf(stderr, "using implicit target address %s\n", ipstr);
	}

	while ((ch = getopt(argc, argv, "n:i:t:m:s:hg")) != -1) {
		 switch (ch) {
            case 'n':
				limit = atoi(optarg);
				fprintf(stderr, "sending %d bytes %d times\n", msg_bytes, limit);
				break;
            case 'i':
				strncpy(interface , optarg, sizeof(interface)-1);
				bSetInterface = 1;
				break;
			case 't':
				strncpy(target, optarg, MAX_HOSTNAME-1);
				bSetTarget = 1;
				break;
			case 'm':
				strncpy(message, optarg, MAX_MSG_SIZE-1);
				message[MAX_MSG_SIZE-1] = '\0';
				break;
			case 's':
				msg_bytes=atoi(optarg);
				break;
			case 'g':
				generate=1;
				break;
			case 'h':
			default:
				syntax(argv[0]);
				exit(1);
			}
	}
			

	if (bSetTarget) {
		fprintf(stderr, "trying to look for %s\n", target);
	}
	else {
		// use default global broadcast  address
		strcpy(target , ipstr);
		fprintf(stderr, "using default target %s\n", target);
	}

	// check if it is an IP address
	if (1 == inet_aton(target, &ip)) {	// ok, seems to be an IP
		fprintf(stderr, "ok, %s is ip\n", inet_ntoa(ip));
		/* if ((he=gethostbyaddr((const void *)&ip, sizeof(ip), AF_INET)) == NULL)  {
			herror("gethostbyaddr() failed");
			exit(1);
		}
		*/
	}
	// if not, check if we can do a gethostbyname
	else if ((he=gethostbyname(target)) != NULL) {
		ip = *(struct in_addr*)he->h_addr;
		fprintf(stderr, "DNS worked; %s has address %s\n", target, inet_ntoa(ip));
	}	
	else {
		fprintf(stderr, "could not resolve ip nor host name, giving up\n");
		exit(1);
	}

	// generate
	if (generate) {
		for (i=0; i< MAX_MSG_SIZE-1;i++) {
			message[i] = (char)random();
		}
		message[MAX_MSG_SIZE-1] = 0;

	}
	// set to UDP
    if ((sockfd = socket(AF_INET, SOCK_DGRAM, 0)) == -1) {
        perror("socket");
        exit(1);
    }

    // this call is what allows broadcast packets to be sent:
    if (setsockopt(sockfd, SOL_SOCKET, SO_BROADCAST, &broadcast,
        sizeof broadcast) == -1) {
        perror("setsockopt (SO_BROADCAST)");
        exit(1);
    }
	// if an interface was given, bind to it
	if (bSetInterface) {
#if !defined(SO_BINDTODEVICE)
		fprintf(stderr, "can not not bind to specific device on this system. Sending anyway\n");
#else
		if (setsockopt(sockfd, SOL_SOCKET, SO_BINDTODEVICE, interface, strlen(interface))) {	
			perror("setsockopt (SO_BINDTODEVICE)");
			exit(-3);
		}
#endif
	}

    remote_addr.sin_family = AF_INET;     // host byte order
    remote_addr.sin_port = htons(SERVERPORT); // short, network byte order
    remote_addr.sin_addr = ip; // *((struct in_addr *)he->h_addr);
    memset(remote_addr.sin_zero, '\0', sizeof remote_addr.sin_zero);

	for (i=0; i < limit; i++) {
		if ( (numbytes=sendto(sockfd, message, msg_bytes, 0, (struct sockaddr *)&remote_addr, sizeof remote_addr)) == -1) {
			perror("sendto");
			exit(1);
		}
		total_bytes+=numbytes;
	}

    printf("sent %d bytes to %s, %i times, total: %lu bytes\n", numbytes,
        inet_ntoa(remote_addr.sin_addr), limit, total_bytes);
	// printf("  %u pckts/sec, duration: %lf sec\n", pckts_sec, duration);

    close(sockfd);

    return 0;
}
