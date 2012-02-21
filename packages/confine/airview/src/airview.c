#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>

/* change this definition for the correct port */
#define MODEMDEVICE "/dev/ttyACM0"

#define FALSE 0
#define TRUE 1

volatile int STOP=FALSE;
const char* gdi = "\ngdi\n";
const char* init = "\ninit\n";
const char* bs = "\nbs\n";
const char* es = "\nes\n";

int main(int argc, char* argv[])
{
    int fd, res;
    struct termios oldtio,newtio;
    char buf[255];

    /*
     * open modem device for reading and writing and not as controlling tty
     * because we don't want to get killed if linenoise sends ctrl-c.
     */
    fd = open(MODEMDEVICE, O_RDWR | O_NOCTTY );
    if (fd <0) {
        perror(MODEMDEVICE);
        exit(-1);
    }

    tcgetattr(fd, &oldtio); /* save current serial port settings */
    bzero(&newtio, sizeof(newtio)); /* clear struct for new port settings*/

    /*
     * baudrate: set bps rate. you could also use cfsetispeed and cfsetospeed.
     * crtscts : output hardware flow control (only used if the cable has
     *           all necessary lines. see sect. 7 of serial-howto)
     * cs8     : 8n1 (8bit,no parity,1 stopbit)
     * clocal  : local connection, no modem contol
     * cread   : enable receiving characters
     */
    newtio.c_cflag = B9600 | CRTSCTS | CS8 | CLOCAL | CREAD;

    /*
     * ignpar  : ignore bytes with parity errors
     * icrnl   : map cr to nl (otherwise a cr input on the other computer
     *           will not terminate input)
     *           otherwise make device raw (no other input processing)
     */
    newtio.c_iflag = IGNPAR | ICRNL;

    /*
     * raw output.
     */
    newtio.c_oflag = 0;

    /*
     * icanon  : enable canonical input
     *           disable all echo functionality, and don't send signals to calling
     *           program
     */
    newtio.c_lflag = ICANON;

    /*
     * initialize all control characters
     * default values can be found in /usr/include/termios.h, and are given
     * in the comments, but we don't need them here
     */

    newtio.c_cc[VINTR]    = 0xa;     /* ctrl-c */
    newtio.c_cc[VQUIT]    = 0;     /* ctrl-\ */
    newtio.c_cc[VERASE]   = 0;     /* del */
    newtio.c_cc[VKILL]    = 0;     /* @ */
    newtio.c_cc[VEOF]     = 4;     /* EOF = 0x04 */
    newtio.c_cc[VSTART]   = 0;     /* ctrl-q */
    newtio.c_cc[VSTOP]    = 0;     /* ctrl-s */

    /*
     * now clean the modem line and activate the settings for the port
     */
    tcflush(fd, TCIFLUSH);
    tcsetattr(fd,TCSANOW,&newtio);

    // second round

    newtio.c_cc[VTIME]    = 10;

    tcflush(fd, TCIFLUSH);
    tcsetattr(fd,TCSANOW,&newtio);

    // third round

    newtio.c_cflag = B115200 | CRTSCTS | CS8 | CLOCAL | CREAD;

    tcflush(fd, TCIFLUSH);
    tcsetattr(fd,TCSANOW,&newtio);

    // initial setup done

    printf("initial port setting: done.\n");

    // get device information

    res = write(fd, gdi, strlen(gdi));
    if (res < strlen(gdi)) {
        perror("write(gdi)");
        exit(-1);
    }

    res = read(fd,buf,255);
    if(res > 0) {
        buf[res]=0; /* set end of string, so we can printf */
        printf("%s", buf);
    }

    // init the device

    res = write(fd, init, strlen(init));
    if (res < strlen(init)) {
        perror("write(init)");
        exit(-1);
    }

    res = read(fd,buf,255);
    if(res > 0) {
        buf[res]=0; /* set end of string, so we can printf */
        printf("%s", buf);
    }

    res = write(fd,bs,strlen(bs));
    /*
     * terminal settings done, now handle input
    */
    while (STOP==FALSE) {     /* loop until we have a terminating condition */
        res = read(fd,buf,255);
        buf[res]=0;             /* set end of string, so we can printf */
        if(res > 0)
            printf("%s", buf);
    }

    /* restore the old port settings */
    tcsetattr(fd,TCSANOW,&oldtio);

    return 0;
}
