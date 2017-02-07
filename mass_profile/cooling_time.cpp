#include <iostream>
#include <fstream>
#include <cmath>
#include "spline.hpp"


using namespace std;
const double kB=1.60217646E-9;//erg/keV
const double pi=atan(1)*4;
int main(int argc,char* argv[])
{
  if(argc!=6)
    {
      cerr<<"Usage:"<<argv[0]<<" <rho_fit.dat> <T file> <bolo cooling function file> <dl> <cm_per_pixel>"<<endl;
      return -1;
    }
  double cm_per_pixel=atof(argv[5]);
  double dl=atof(argv[4]);
  spline<double> cf,t_profile;
  ifstream ifs(argv[2]);
  for(;;)
    {
      double x,T;
      ifs>>x>>T;
      if(!ifs.good())
	{
	  break;
	}
      x=x*cm_per_pixel/3.08567758E21;//convert to kpc
      t_profile.push_point(x,T);
    }
  t_profile.gen_spline(0,0);
  ifs.close();
  ifs.open(argv[3]);
  for(;;)
    {
      double x,c;
      ifs>>x>>c;
      if(!ifs.good())
	{
	  break;
	}
      x=x*cm_per_pixel/3.08567758E21;//convert to kpc
      cf.push_point(x,c);
    }
  cf.gen_spline(0,0);

  ifs.close();
  ifs.open(argv[1]);
  for(;;)
    {
      double r,ne;
      ifs>>r>>ne;
      if(!ifs.good())
	{
	  break;
	}
      double nh=ne*1.2;
      double tcool=3./2.*(ne+nh)*kB*t_profile.get_value(r)/ne/nh/(cf.get_value(r)*4*pi*dl*dl);//s;
      cout<<r<<"\t"<<tcool/(24*3600*365*1E9)<<endl;
    }
}
