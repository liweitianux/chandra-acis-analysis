/*
  Fitting nfw mass profile model
  Author: Junhua Gu
  Last modification 20120721
*/

#include "nfw.hpp"
#include <core/optimizer.hpp>
#include <core/fitter.hpp>
#include <data_sets/default_data_set.hpp>
#include "chisq.hpp"
#include <methods/powell/powell_method.hpp>
#include <iostream>
#include <fstream>
#include <vector>
#include <string>

using namespace opt_utilities;
using namespace std;
const double cm=1;
const double kpc=3.08568e+21*cm;
const double pi=4*atan(1);
static double calc_critical_density(double z,
				    const double H0=2.3E-18,
				    const double Omega_m=.27)
{
  const double G=6.673E-8;//cm^3 g^-1 s^2
  const double E=std::sqrt(Omega_m*(1+z)*(1+z)*(1+z)+1-Omega_m);
  const double H=H0*E;
  return 3*H*H/8/pi/G;
}


int main(int argc,char* argv[])
{
  if(argc<3)
    {
      cerr<<"Usage:"<<argv[0]<<" <data file with 4 columns of x, xe, y, ye> <z> [rmin in kpc]"<<endl;
      return -1;
    }
  double rmin_kpc=1;
  if(argc>=4)
    {
      rmin_kpc=atof(argv[3]);
    }
  double z=0;
  z=atof(argv[2]);
  //define the fitter
  fitter<double,double,vector<double>,double,std::string> fit;
  //define the data set
  default_data_set<double,double> ds;
  //open the data file
  ifstream ifs(argv[1]);
  //cout<<"read serr 2"<<endl;
  ofstream ofs_fit_result("nfw_fit_result.qdp");

  ofs_fit_result<<"read serr 1 2"<<endl;
  ofs_fit_result<<"skip single"<<endl;
  ofs_fit_result<<"line off"<<endl;
  ofs_fit_result<<"li on 2"<<endl;
  ofs_fit_result<<"li on 4"<<endl;
  ofs_fit_result<<"ls 2 on 4"<<endl;

  ofs_fit_result<<"win 1"<<endl;
  ofs_fit_result<<"yplot 1 2"<<endl;
  ofs_fit_result<<"loc 0 0 1 1"<<endl;
  ofs_fit_result<<"vie .1 .4 .9 .9"<<endl;
  ofs_fit_result<<"la y Mass (solar)"<<endl;
  ofs_fit_result<<"log x"<<endl;
  ofs_fit_result<<"log y"<<endl;
  ofs_fit_result<<"win 2"<<endl;
  ofs_fit_result<<"yplot 3 4"<<endl;
  ofs_fit_result<<"loc 0 0 1 1"<<endl;
  ofs_fit_result<<"vie .1 .1 .9 .4"<<endl;
  ofs_fit_result<<"la x radius (kpc)"<<endl;
  ofs_fit_result<<"la y chi"<<endl;
  ofs_fit_result<<"log x"<<endl;
  ofs_fit_result<<"log y off"<<endl;
  for(;;)
    {
      //read radius, temperature and error
      double r,re,m,me;
      ifs>>r>>re>>m>>me;
      if(!ifs.good())
	{
	  break;
	}
      if(r<rmin_kpc)
	{
	  continue;
	}
      data<double,double> d(r,m,me,me,re,re);
      ofs_fit_result<<r<<"\t"<<re<<"\t"<<m<<"\t"<<me<<endl;
      ds.add_data(d);
    }
  ofs_fit_result<<"no no no"<<endl;
  //load data
  fit.load_data(ds);
  //define the optimization method
  fit.set_opt_method(powell_method<double,vector<double> >());
  //use chi^2 statistic
  fit.set_statistic(chisq<double,double,vector<double>,double,std::string>());
  fit.set_model(nfw<double>());
  //fit.set_param_value("rs",4);
  //fit.set_param_value("rho0",100);
  fit.fit();
  fit.fit();
  vector<double> p=fit.fit();
  //output parameters
  ofstream ofs_param("nfw_param.txt");
  for(size_t i=0;i<fit.get_num_params();++i)
    {
      cout<<fit.get_param_info(i).get_name()<<"\t"<<fit.get_param_info(i).get_value()<<endl;
      ofs_param<<fit.get_param_info(i).get_name()<<"\t"<<fit.get_param_info(i).get_value()<<endl;
    }
  cout<<"reduced chi^2="<<fit.get_statistic_value()<<endl;
  ofs_param<<"reduced chi^2="<<fit.get_statistic_value()<<endl;
  ofstream ofs_model("nfw_dump.qdp");
  ofstream ofs_overdensity("overdensity.qdp");
  //const double G=6.673E-8;//cm^3 g^-1 s^-2
  //static const double mu=1.4074;
  //static const double mp=1.67262158E-24;//g
  static const double M_sun=1.98892E33;//g
  //static const double k=1.38E-16;

  double xmax=0;
  for(double x=std::max(rmin_kpc,ds.get_data(0).get_x());;x+=1)
    {
      double model_value=fit.eval_model(x,p);
      ofs_model<<x<<"\t"<<model_value<<endl;
      ofs_fit_result<<x<<"\t0\t"<<model_value<<"\t0"<<endl;
      double V=4./3.*pi*pow(x*kpc,3);
      double m=model_value*M_sun;
      double rho=m/V;//g/cm^3
      double over_density=rho/calc_critical_density(z);
      ofs_overdensity<<x<<"\t"<<over_density<<endl;
      xmax=x;
      if(over_density<100)
	{
	  break;
	}
    }
  ofs_fit_result<<"no no no"<<endl;
  for(size_t i=0;i<ds.size();++i)
    {
      data<double,double> d=ds.get_data(i);
      double x=d.get_x();
      double y=d.get_y();
      double ye=d.get_y_lower_err();
      double ym=fit.eval_model(x,p);
      ofs_fit_result<<x<<"\t"<<0<<"\t"<<(y-ym)/ye<<"\t"<<1<<endl;
    }
  ofs_fit_result<<"no no no"<<endl;
  for(double x=std::max(rmin_kpc,ds.get_data(0).get_x());x<xmax;x+=1)
    {
      ofs_fit_result<<x<<"\t"<<0<<"\t"<<0<<"\t"<<0<<endl;
    }

}
