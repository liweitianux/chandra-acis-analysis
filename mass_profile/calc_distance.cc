#include <iostream>
#include <cmath>
#include <cstdlib>
#include <cstddef>
#include <cassert>
#include "adapt_trapezoid.h"

//calc_distance
//usage:
//calc_distance z

using namespace std;

static double cm=1;
static double s=1;
static double km=1000*100;
static double Mpc=3.08568e+24*cm;
static double kpc=3.08568e+21*cm;
static double yr=365.*24.*3600.;
static double Gyr=1e9*yr;
static double H=71.*km/s/Mpc;
static const double c=299792458.*100.*cm;
//const double c=3e8*100*cm;
static const double omega_m=0.27;
static const double omega_l=0.73;
static const double arcsec2arc_ratio=1./60/60/180*3.1415926;


double E(double z)
{
  double omega_k=1-omega_m-omega_l;
  return sqrt(omega_m*(1+z)*(1+z)*(1+z)+omega_k*(1+z)*(1+z)+omega_l);
}

double f_dist(double z)
{
  return 1/E(z);
}

double f_age(double z)
{
  return f_dist(1/z)/(z*z);
}



double calc_angular_distance(double z)
{
  //return c/H*integer(f_dist,0,z)/(1+z);
  //return c/H*adapt_trapezoid(f_dist,0.,z,1e-4)/(1+z);
  return adapt_trapezoid(f_dist,0.,z,1e-4)/(1+z);
}

double calc_luminosity_distance(double z)
{
  //return c/H*integer(f_dist,0,z)/(1+z);
  return c/H*adapt_trapezoid(f_dist,0.,z,1e-4)*(1+z);
}


//EOF
