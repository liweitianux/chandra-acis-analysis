#include "calc_distance.h"
#include "spline.hpp"
#include <iostream>
#include <string>
#include <vector>
#include <statistics/chisq.hpp>
#include <methods/powell/powell_method.hpp>
#include <data_sets/default_data_set.hpp>
#include <misc/data_loaders.hpp>
#include "methods/aga/aga.hpp"
#include <models/beta1d.hpp>
#include <cstdlib>
using namespace std;
using namespace opt_utilities;


static const double cm=1;
static const double s=1;
static const double km=1000*100;
static const double Mpc=3.08568e+24*cm;
static const double kpc=3.08568e+21*cm;
static const double yr=365.*24.*3600.;
static const double Gyr=1e9*yr;
static const double H=71.*km/s/Mpc;
static const double c=299792458.*100.*cm;
//const double c=3e8*100*cm;
static const double pi=4*atan(1);
static const double omega_m=0.27;
static const double omega_l=0.73;
static const double arcsec2arc_ratio=1./60/60/180*pi;

double std_norm_rand()
{
  double u=0;
  double v=0;
  while(u<=0||v<=0)
    {
      u=rand()/(double)RAND_MAX;
      rand();
      v=rand()/(double)RAND_MAX;
    }
  double x=std::sqrt(-log(u))*cos(2*pi*v);
  return x;
}


int main(int argc,char* argv[])
{
  srand(time(0));
  if(argc<5)
    {
      cerr<<"Usage:"<<argv[0]<<" <sbp data> <ratio file> <z> <r500 in kpc> [Tprofile.dat]"<<endl;
      return -1;
    }
  double z=atof(argv[3]);
  assert(z>0);
  double d_a_cm=c/H*calc_angular_distance(z);
  double d_l_cm=(1+z)*(1+z)*d_a_cm;
  double cm_per_pixel=d_a_cm*.492*arcsec2arc_ratio;
  //////////////////////////////
  //perform a 1-beta fitting////
  //////////////////////////////
  fitter<double,double,vector<double>,double,string> f;

  f.set_statistic(chisq<double,double,vector<double>,double,string>());
  f.set_opt_method(powell_method<double,vector<double> >());
  f.set_model(beta1d<double>());
  dl_x_xe_y_ye<double,double> dl;
  ifstream ifs(argv[1]);
  ifs>>dl;
  f.load_data(dl.get_data_set());
  f.fit();
  double rmin=f.get_data_set().get_data(0).get_x();
  double rmax=f.get_data_set().get_data(f.get_data_set().size()-1).get_x();
  ofstream lx_fit_result("lx_fit_result.qdp");
  lx_fit_result<<"read terr 1 2\nskip single\n";
  for(size_t i=0;i<f.get_data_set().size();++i)
    {
      lx_fit_result<<f.get_data_set().get_data(i).get_x()<<"\t"<<
	-abs(f.get_data_set().get_data(i).get_x_lower_err())<<"\t"<<
	abs(f.get_data_set().get_data(i).get_x_upper_err())<<"\t"<<
	f.get_data_set().get_data(i).get_y()<<"\t"<<
	-abs(f.get_data_set().get_data(i).get_y_lower_err())<<"\t"<<
	abs(f.get_data_set().get_data(i).get_y_upper_err())<<endl;
    }
  lx_fit_result<<"no no no\n";

  for(double i=rmin;i<rmax;i+=1)
    {
      lx_fit_result<<i<<"\t0\t0\t"<<f.eval_model(i,f.get_all_params())<<"\t0\t0"<<endl;
    }

  for(size_t i=0;i<f.get_num_params();++i)
    {
      cerr<<f.get_param_info(i).get_name()<<"="<<
	f.get_param_info(i).get_value()<<endl;
    }

  vector<double> p=f.get_all_params();

  double r500kpc=atof(argv[4]);
  assert(r500kpc>0);
  double r500pixel=r500kpc*kpc/cm_per_pixel;

  const double dr=1;
  double sum_cnt=0;
  double sum_flux=0;
  spline<double> spl;
  ifstream ifs_ratio(argv[2]);
  assert(ifs_ratio.is_open());
  for(;;)
    {
      double x,y;
      ifs_ratio>>x>>y;
      if(!ifs_ratio.good())
	{
	  break;
	}
      spl.push_point(x,y);
    }
  spl.gen_spline(0,0);

  for(double r=0;r<r500pixel;r+=dr)
    {
      double r1=r<.2*r500pixel?.2*r500pixel:r;
      double sbp=f.eval_model_raw(r1,p);
      double cnt=sbp*pi*(2*r+dr)*dr;
      double ratio=spl.get_value(r);
      //cerr<<sbp<<endl;
      sum_cnt+=cnt;
      sum_flux+=cnt*ratio;
    }
  double lx=sum_flux*4*pi*d_l_cm*d_l_cm;

  double l_mean=0;
  double l2_mean=0;
  double cnt=0;
  for(int n=0;n<100;++n)
    {
      cerr<<".";
      opt_utilities::default_data_set<double,double> ds(dl.get_data_set());
      opt_utilities::default_data_set<double,double> ds1;
      for(size_t i=0;i<ds.size();++i)
	{
	  double yc=ds.get_data(i).get_y();
	  double ye=(std::abs(ds.get_data(i).get_y_lower_err())+std::abs(ds.get_data(i).get_y_lower_err()))/2;
	  double xc=ds.get_data(i).get_x();
	  double xe=(std::abs(ds.get_data(i).get_x_lower_err())+std::abs(ds.get_data(i).get_x_lower_err()))/2;
	  double newy=std_norm_rand()*ye+yc;
	  //cout<<yc<<"\t"<<newy<<endl;
	  ds1.add_data(data<double,double>(xc,newy,ye,ye,xe,xe));
	}
      f.load_data(ds1);
      chisq<double,double,vector<double>,double,string> c;
      //c.verbose(true);
      f.set_statistic(c);
      f.fit();
      vector<double> p=f.get_all_params();
      //cout<<f.get_param_value("beta")<<endl;
      double sum_cnt=0;
      double sum_flux=0;

      for(double r=0;r<r500pixel;r+=dr)
	{
	  double r1=r<.2*r500pixel?.2*r500pixel:r;
	  double sbp=f.eval_model_raw(r1,p);
	  double cnt=sbp*pi*(2*r+dr)*dr;
	  double ratio=spl.get_value(r);
	  sum_cnt+=cnt;
	  sum_flux+=cnt*ratio;
	}
      //cout<<sum_cnt<<endl;
      double lx=sum_flux*4*pi*d_l_cm*d_l_cm;
      l_mean+=lx;
      l2_mean+=lx*lx;
      cnt+=1;
      //std::cerr<<lx<<endl;
      //std::cerr<<f.get_param_value(
    }
  l_mean/=cnt;
  l2_mean/=cnt;
  cerr<<endl;
  double std_l=std::sqrt(l2_mean-l_mean*l_mean);

  double std_l2=0;
  if(argc==6)
    {
      ifstream ifs_tfile(argv[5]);
      assert(ifs_tfile.is_open());
      double mean_T=0;
      int cnt=0;
      double mean_Te=0;
      for(;;)
	{
	  double r,re,t,te;
	  ifs_tfile>>r>>re>>t>>te;
	  if(!ifs_tfile.good())
	    {
	      break;
	    }
	  cnt+=1;
	  mean_T+=t;
	  mean_Te+=te*te;
	}
      mean_T/=cnt;
      mean_Te/=cnt;
      mean_Te=std::sqrt(mean_Te);
      if(mean_Te>mean_T)
	{
	  mean_Te=mean_T;
	}
      std_l2=mean_Te/mean_T*lx;
      //cout<<mean_Te<<"\t"<<mean_T<<endl;
    }
  std_l=std::sqrt(std_l*std_l+std_l2*std_l2);
  std::cout<<"Lx(bol): "<<lx<<" +/- "<<std_l<<" erg/s #Lx(bol) within r500"<<std::endl;
  //std::cout<<sum_cnt<<std::endl;
}
