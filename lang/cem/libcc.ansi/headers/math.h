/*
 * math.h - mathematics
 */
/* $Header$ */

#if	!defined(_MATH_H)
#define	_MATH_H

#define	HUGE_VAL	9.9e+999	/* though it will generate a warning */

double	acos(double _x);
double	asin(double _x);
double	atan(double _x);
double	atan2(double _y, double _x);

double	cos(double _x);
double	sin(double _x);
double	tan(double _x);

double	cosh(double _x);
double	sinh(double _x);
double	tanh(double _x);

double	exp(double _x);
double	log(double _x);
double	log10(double _x);

double	sqrt(double _x);
double	ceil(double _x);
double	fabs(double _x);
double	floor(double _x);

double	pow(double _x, double _y);

double	frexp(double _x, int *_exp);
double	ldexp(double _x, int _exp);
double	modf(double _x, double *_iptr);
double	fmod(double _x, double _y);

#endif	/* _MATH_H */
