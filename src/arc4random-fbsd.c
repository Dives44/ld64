/* Libc-498.1.1/gen/arc4random-fbsd.c (modified) */
/*
 * Arc4 random number generator for OpenBSD.
 * Copyright 1996 David Mazieres <dm@lcs.mit.edu>.
 *
 * Modification and redistribution in source and binary forms is
 * permitted provided that due credit is given to the author and the
 * OpenBSD project (for instance by leaving this copyright notice
 * intact).
 */

/*
 * This code is derived from section 17.1 of Applied Cryptography,
 * second edition, which describes a stream cipher allegedly
 * compatible with RSA Labs "RC4" cipher (the actual description of
 * which is a trade secret).  The same algorithm is used as a stream
 * cipher called "arcfour" in Tatu Ylonen's ssh package.
 *
 * Here the stream cipher has been modified always to include the time
 * when initializing the state.  That makes it impossible to
 * regenerate the same random sequence twice, so this can't be used
 * for encryption, but will generate good random numbers.
 *
 * RC4 is a registered trademark of RSA Laboratories.
 */

#include "arc4random.h"

#include <sys/cdefs.h>

#include <sys/types.h>
#include <sys/time.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <pthread.h>

struct arc4_stream {
	u_int8_t i;
	u_int8_t j;
	u_int8_t s[256];
};

static pthread_mutex_t	arc4random_mtx = PTHREAD_MUTEX_INITIALIZER;

#define	RANDOMDEV	"/dev/urandom"
#define	THREAD_LOCK()						\
	do {							\
		pthread_mutex_lock(&arc4random_mtx);		\
	} while (0)

#define	THREAD_UNLOCK()						\
	do {							\
		pthread_mutex_unlock(&arc4random_mtx);		\
	} while (0)

static struct arc4_stream rs;
static int rs_initialized;
static int rs_stired;

static inline u_int8_t arc4_getbyte(struct arc4_stream *);
static void arc4_stir(struct arc4_stream *);

static inline void
arc4_init(as)
	struct arc4_stream *as;
{
	int     n;

	for (n = 0; n < 256; n++)
		as->s[n] = n;
	as->i = 0;
	as->j = 0;
}

static inline void
arc4_addrandom(as, dat, datlen)
	struct arc4_stream *as;
	u_char *dat;
	int     datlen;
{
	int     n;
	u_int8_t si;

	as->i--;
	for (n = 0; n < 256; n++) {
		as->i = (as->i + 1);
		si = as->s[as->i];
		as->j = (as->j + si + dat[n % datlen]);
		as->s[as->i] = as->s[as->j];
		as->s[as->j] = si;
	}
}

static void
arc4_stir(as)
	struct arc4_stream *as;
{
	int     fd, n;
	struct {
		struct timeval tv;
		pid_t pid;
		u_int8_t rnd[128 - sizeof(struct timeval) - sizeof(pid_t)];
	}       rdat;

	gettimeofday(&rdat.tv, NULL);
	rdat.pid = getpid();
	fd = open(RANDOMDEV, O_RDONLY, 0);
	if (fd >= 0) {
		(void) read(fd, rdat.rnd, sizeof(rdat.rnd));
		close(fd);
	} 
	/* fd < 0?  Ah, what the heck. We'll just take whatever was on the
	 * stack... */

	arc4_addrandom(as, (u_char *) &rdat, sizeof(rdat));

	/*
	 * Throw away the first N bytes of output, as suggested in the
	 * paper "Weaknesses in the Key Scheduling Algorithm of RC4"
	 * by Fluher, Mantin, and Shamir.  N=1024 is based on
	 * suggestions in the paper "(Not So) Random Shuffles of RC4"
	 * by Ilya Mironov.
	 */
	for (n = 0; n < 1024; n++)
		arc4_getbyte(as);
}

static inline u_int8_t
arc4_getbyte(as)
	struct arc4_stream *as;
{
	u_int8_t si, sj;

	as->i = (as->i + 1);
	si = as->s[as->i];
	as->j = (as->j + si);
	sj = as->s[as->j];
	as->s[as->i] = sj;
	as->s[as->j] = si;

	return (as->s[(si + sj) & 0xff]);
}

static inline u_int32_t
arc4_getword(as)
	struct arc4_stream *as;
{
	u_int32_t val;

	val = arc4_getbyte(as) << 24;
	val |= arc4_getbyte(as) << 16;
	val |= arc4_getbyte(as) << 8;
	val |= arc4_getbyte(as);

	return (val);
}

static void
arc4_check_init(void)
{
	if (!rs_initialized) {
		arc4_init(&rs);
		rs_initialized = 1;
	}
}

static void
arc4_check_stir(void)
{
	if (!rs_stired) {
		arc4_stir(&rs);
		rs_stired = 1;
	}
}

void
arc4random_stir()
{
	THREAD_LOCK();
	arc4_check_init();
	arc4_stir(&rs);
	THREAD_UNLOCK();
}

void
arc4random_addrandom(dat, datlen)
	u_char *dat;
	int     datlen;
{
	THREAD_LOCK();
	arc4_check_init();
	arc4_check_stir();
	arc4_addrandom(&rs, dat, datlen);
	THREAD_UNLOCK();
}

u_int32_t
arc4random()
{
	u_int32_t rnd;

	THREAD_LOCK();
	arc4_check_init();
	arc4_check_stir();
	rnd = arc4_getword(&rs);
	THREAD_UNLOCK();

	return (rnd);
}

#if 0
/*-------- Test code for i386 --------*/
#include <stdio.h>
#include <machine/pctr.h>
int
main(int argc, char **argv)
{
	const int iter = 1000000;
	int     i;
	pctrval v;

	v = rdtsc();
	for (i = 0; i < iter; i++)
		arc4random();
	v = rdtsc() - v;
	v /= iter;

	printf("%qd cycles\n", v);
}
#endif
