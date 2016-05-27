#include "calc_distance.h"
#include <cstdlib>
#include <cmath>
#include <iostream>
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
static const double pi=4*atan(1);
static const double omega_m=0.27;
static const double omega_l=0.73;
static const double arcsec2arc_ratio=1./60/60/180*pi;




int main(int argc,char* argv[])
{
  if(argc<2)
    {
      cerr<<"Usage:"<<argv[0]<<" z"<<endl;
      exit(-1);
    }
  if(argc==3)
    {
      H=atof(argv[2])*km/s/Mpc;
    }
  double z=atof(argv[1]);
  double d=c/H*calc_angular_distance(z);
  //double age=calc_age(z);
  //cout<<d<<endl;
  cout<<"d_a_cm= "<<d<<" #angular distance in cm"<<endl;
  cout<<"d_a_mpc= "<<d/Mpc<<"#angular distance in Mpc"<<endl;
  cout<<"d_l_cm= "<<(1+z)*(1+z)*d<<" #luminosity distance in cm"<<endl;
  cout<<"d_l_mpc= "<<(1+z)*(1+z)*d/Mpc<<" #luminosity in Mpc"<<endl;
  cout<<"kpc_per_sec= "<<d/kpc*arcsec2arc_ratio<<" #kpc per arcsec"<<endl;
  cout<<"For Chandra:"<<endl;
  cout<<"kpc_per_pixel= "<<d/kpc*0.492*arcsec2arc_ratio<<" #kpc per chandra pixel"<<endl;
  cout<<"cm_per_pixel= "<<d*.492*arcsec2arc_ratio<<" #cm per chandra pixel"<<endl;
  cout<<"norm= "<<1E-14/(4*pi*pow(d*(1+z),2))<<" #norm used to calc cooling function"<<endl;
  //cout<<ddivid(calc_distance,d,0,1,.0001)<<endl;
  cout<<"E(z)= "<<E(z)<<endl;
}

