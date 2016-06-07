/*
  Perform a double-beta density model fitting to the surface brightness data
  Author: Junhua Gu
  Last modified: 2016.06.07
  This code is distributed with no warrant
*/


#include <iostream>
#include <fstream>
#include <list>
using namespace std;
#include "vchisq.hpp"
#include "dbeta.hpp"
#include "beta_cfg.hpp"
#include <data_sets/default_data_set.hpp>
#include <methods/powell/powell_method.hpp>
#include <core/freeze_param.hpp>
#include <error_estimator/error_estimator.hpp>
#include "spline.h"
using namespace opt_utilities;
//double s=5.63136645E20;
const double kpc=3.086E21;//kpc in cm
const double Mpc=kpc*1000;
double dbeta_func(double r,
		  double n01,double rc1,double beta1,
		  double n02,double rc2,double beta2)
{

  return abs(n01)*pow(1+r*r/rc1/rc1,-3./2.*abs(beta1))+abs(n02)*pow(1+r*r/rc2/rc2,-3./2.*abs(beta2));
}


  //calculate critical density from z, under following cosmological constants
static double calc_critical_density(double z,
				    const double H0=2.3E-18,
				      const double Omega_m=.27)
{
  const double G=6.673E-8;//cm^3 g^-1 s^2
  const double E=std::sqrt(Omega_m*(1+z)*(1+z)*(1+z)+1-Omega_m);
  const double H=H0*E;
  return 3*H*H/8/pi/G;
}


//A class enclosing the spline interpolation method of cooling function
//check spline.h for more detailed information
//this class is a thin wrapper for the spline class defined in spline.h
class spline_func_obj
  :public func_obj<double,double>
{
  //has an spline object
  spline<double> spl;
public:
  //This function is used to calculate the intepolated value
  double do_eval(const double& x)
  {
    return spl.get_value(x);
  }

  //we need this function, when this object is performing a clone of itself
  spline_func_obj* do_clone()const
  {
    return new spline_func_obj(*this);
  }

public:
  //add points to the spline object, after which the spline will be initialized
  void add_point(double x,double y)
  {
    spl.push_point(x,y);
  }

  //before getting the intepolated value, the spline should be initialzied by calling this function
  void gen_spline()
  {
    spl.gen_spline(0,0);
  }
};

int main(int argc,char* argv[])
{
  if(argc!=2)
    {
      cerr<<argv[0]<<" <configure file>"<<endl;
      return -1;
    }
  //initialize the parameters list
  ifstream cfg_file(argv[1]);
  assert(cfg_file.is_open());
  cfg_map cfg=parse_cfg_file(cfg_file);

  //check the existence of following parameters

  const double z=cfg.z;

  //initialize the radius list, sbp list and sbp error list
  std::vector<double> radii;
  std::vector<double> sbps;
  std::vector<double> sbpe;
  std::vector<double> radii_all;
  std::vector<double> sbps_all;
  std::vector<double> sbpe_all;
  //read sbp and sbp error data
  for(ifstream ifs(cfg.sbp_file.c_str());;)
    {
      assert(ifs.is_open());
      double x,xe;
      ifs>>x>>xe;
      if(!ifs.good())
	{
	  break;
	}
      if(x/xe<2)
	{
	  break;
	}
      cerr<<x<<"\t"<<xe<<endl;
      sbps.push_back(x);
      sbpe.push_back(xe);
      sbps_all.push_back(x);
      sbpe_all.push_back(xe);
    }

  //read radius data
  for(ifstream ifs(cfg.radius_file.c_str());;)
    {
      assert(ifs.is_open());
      double x;
      ifs>>x;
      if(!ifs.good())
	{
	  break;
	}
      cerr<<x<<endl;
      radii.push_back(x);
      radii_all.push_back(x);
    }
  //initialize the cm/pixel value
  double cm_per_pixel=cfg.cm_per_pixel;
  double rmin=5*kpc/cm_per_pixel;
  if(cfg.rmin_pixel>0)
    {
      rmin=cfg.rmin_pixel;
    }
  else
    {
      rmin=cfg.rmin_kpc*kpc/cm_per_pixel;
    }

  cerr<<"rmin="<<rmin<<endl;
  std::list<double> radii_tmp,sbps_tmp,sbpe_tmp;
  radii_tmp.resize(radii.size());
  sbps_tmp.resize(sbps.size());
  sbpe_tmp.resize(sbpe.size());
  copy(radii.begin(),radii.end(),radii_tmp.begin());
  copy(sbps.begin(),sbps.end(),sbps_tmp.begin());
  copy(sbpe.begin(),sbpe.end(),sbpe_tmp.begin());
  for(list<double>::iterator i=radii_tmp.begin();i!=radii_tmp.end();)
    {
      if(*i<rmin)
	{
	  radii_tmp.pop_front();
	  sbps_tmp.pop_front();
	  sbpe_tmp.pop_front();
	  i=radii_tmp.begin();
	  continue;
	}
      ++i;
    }
  radii.resize(radii_tmp.size());
  sbps.resize(sbps_tmp.size());
  sbpe.resize(sbpe_tmp.size());
  copy(radii_tmp.begin(),radii_tmp.end(),radii.begin());
  copy(sbps_tmp.begin(),sbps_tmp.end(),sbps.begin());
  copy(sbpe_tmp.begin(),sbpe_tmp.end(),sbpe.begin());

  //read cooling function data
  spline_func_obj cf;
  for(ifstream ifs(cfg.cfunc_file.c_str());;)
    {
      assert(ifs.is_open());
      double x,y,y1,y2;
      ifs>>x>>y;
      if(!ifs.good())
	{
	  break;
	}
      cerr<<x<<"\t"<<y<<endl;
      if(x>radii.back())
	{
	  break;
	}
      //cf.add_point(x,y*2.1249719395939022e-68);//change with source
      cf.add_point(x,y);//change with source
    }
  cf.gen_spline();

  //read temperature profile data
  spline_func_obj Tprof;
  int tcnt=0;
  for(ifstream ifs1(cfg.T_file.c_str());;++tcnt)
    {
      assert(ifs1.is_open());
      double x,y;
      ifs1>>x>>y;
      if(!ifs1.good())
      {
	break;
      }
      cerr<<x<<"\t"<<y<<endl;
#if 0
      if(tcnt==0)
	{
	  Tprof.add_point(0,y);
	}
#endif
      Tprof.add_point(x,y);
    }


  Tprof.gen_spline();

  default_data_set<std::vector<double>,std::vector<double> > ds;
  ds.add_data(data<std::vector<double>,std::vector<double> >(radii,sbps,sbpe,sbpe,radii,radii));

  //initial fitter
  fitter<vector<double>,vector<double>,vector<double>,double> f;
  f.load_data(ds);
  //initial the object, which is used to calculate projection effect
  projector<double> a;
  bool tie_beta=false;
  if(cfg.param_map.find("beta")!=cfg.param_map.end()
     &&cfg.param_map.find("beta1")==cfg.param_map.end()
     &&cfg.param_map.find("beta2")==cfg.param_map.end())
    {
      dbeta2<double> dbetao;
      a.attach_model(dbetao);
      tie_beta=true;
    }
  else if((cfg.param_map.find("beta1")!=cfg.param_map.end()
	   ||cfg.param_map.find("beta2")!=cfg.param_map.end())
	  &&cfg.param_map.find("beta")==cfg.param_map.end())
    {
      dbeta<double> dbetao;
      a.attach_model(dbetao);
      tie_beta=false;
    }
  else
    {
      cerr<<"Error, cannot decide whether to tie beta together or let them vary freely!"<<endl;
      assert(0);
    }

  //attach the cooling function
  a.attach_cfunc(cf);
  a.set_cm_per_pixel(cm_per_pixel);

  f.set_model(a);
  //chi^2 statistic
  vchisq<double> c;
  c.verbose(true);
  c.set_limit();
  f.set_statistic(c);
  //optimization method
  f.set_opt_method(powell_method<double,std::vector<double> >());
  //initialize the initial values
  double n01=0;
  double rc1=0;
  double n02=0;
  double rc2=0;
  double beta=0;
  double bkg=0;
  if(tie_beta)
    {
      f.set_param_value("beta",.7);
      f.set_param_lower_limit("beta",.3);
      f.set_param_upper_limit("beta",1.4);
    }
  else
    {
      f.set_param_value("beta1",.7);
      f.set_param_lower_limit("beta1",.3);
      f.set_param_upper_limit("beta1",1.4);
      f.set_param_value("beta2",.7);
      f.set_param_lower_limit("beta2",.3);
      f.set_param_upper_limit("beta2",1.4);
    }
  for(std::map<std::string,std::vector<double> >::iterator i=cfg.param_map.begin();
      i!=cfg.param_map.end();++i)
    {
      std::string pname=i->first;
      f.set_param_value(pname,i->second.at(0));
      if(i->second.size()==3)
	{
	  double a1=i->second[1];
	  double a2=i->second[2];
	  double u=std::max(a1,a2);
	  double l=std::min(a1,a2);
	  f.set_param_upper_limit(pname,u);
	  f.set_param_lower_limit(pname,l);
	}
      else
	{
	  if(pname=="beta"||pname=="beta1"||pname=="beta2")
	    {
	      f.set_param_lower_limit(pname,.3);
	      f.set_param_upper_limit(pname,1.4);
	    }
	}
    }



  //perform the fitting, first freeze beta1, beta2, rc1, and rc2
  if(tie_beta)
    {
      f.set_param_modifier(freeze_param<std::vector<double>,std::vector<double>,std::vector<double>,std::string>("beta")+
			   freeze_param<std::vector<double>,std::vector<double>,std::vector<double>,std::string>("rc1")+
			   freeze_param<std::vector<double>,std::vector<double>,std::vector<double>,std::string>("rc2")
			   );
    }
  else
    {
      f.set_param_modifier(freeze_param<std::vector<double>,std::vector<double>,std::vector<double>,std::string>("beta1")+
			   freeze_param<std::vector<double>,std::vector<double>,std::vector<double>,std::string>("beta2")+
			   freeze_param<std::vector<double>,std::vector<double>,std::vector<double>,std::string>("rc1")+
			   freeze_param<std::vector<double>,std::vector<double>,std::vector<double>,std::string>("rc2")
			   );
    }

  f.fit();

  f.clear_param_modifier();

  //then perform the fitting, freeze beta1 and beta2
  //f.set_param_modifier(freeze_param<std::vector<double>,std::vector<double>,std::vector<double>,std::string>("beta"));
  //f.set_param_modifier(freeze_param<std::vector<double>,std::vector<double>,std::vector<double>,std::string>("bkg"));
  f.fit();
  //f.clear_param_modifier();

  //finally thaw all parameters
  f.fit();
  double beta1=0;
  double beta2=0;

  n01=f.get_param_value("n01");
  rc1=f.get_param_value("rc1");
  n02=f.get_param_value("n02");
  rc2=f.get_param_value("rc2");
  if(tie_beta)
    {
      beta=f.get_param_value("beta");
      beta1=beta;
      beta2=beta;
    }
  else
    {
      beta1=f.get_param_value("beta1");
      beta2=f.get_param_value("beta2");
    }
  //output the params
  ofstream param_output("dbeta_param.txt");
  //output the datasets and fitting results
  for(int i=0;i<f.get_num_params();++i)
    {
      if(f.get_param_info(i).get_name()=="rc1")
	{
	  cerr<<"rc1_kpc"<<"\t"<<abs(f.get_param_info(i).get_value())*cm_per_pixel/kpc<<endl;
	  param_output<<"rc1_kpc"<<"\t"<<abs(f.get_param_info(i).get_value())*cm_per_pixel/kpc<<endl;
	}
      if(f.get_param_info(i).get_name()=="rc2")
	{
	  cerr<<"rc2_kpc"<<"\t"<<abs(f.get_param_info(i).get_value())*cm_per_pixel/kpc<<endl;
	  param_output<<"rc2_kpc"<<"\t"<<abs(f.get_param_info(i).get_value())*cm_per_pixel/kpc<<endl;
	}
      cerr<<f.get_param_info(i).get_name()<<"\t"<<abs(f.get_param_info(i).get_value())<<endl;
      param_output<<f.get_param_info(i).get_name()<<"\t"<<abs(f.get_param_info(i).get_value())<<endl;
    }
  cerr<<"chi square="<<f.get_statistic_value()/(radii.size()-f.get_model().get_num_free_params())<<endl;
  param_output<<"chi square="<<f.get_statistic_value()/(radii.size()-f.get_model().get_num_free_params())<<endl;

  //c.verbose(false);
  //f.set_statistic(c);
  //f.fit();
  std::vector<double> p=f.get_all_params();
  f.clear_param_modifier();
  std::vector<double> mv=f.eval_model(radii,p);


  ofstream ofs_sbp("sbp_fit.qdp");
  ofs_sbp<<"read serr 2"<<endl;
  ofs_sbp<<"skip single"<<endl;

  ofs_sbp<<"line on 2"<<endl;
  ofs_sbp<<"line on 3"<<endl;
  ofs_sbp<<"line on 4"<<endl;
  ofs_sbp<<"line on 5"<<endl;
  ofs_sbp<<"line on 7"<<endl;
  ofs_sbp<<"ls 2 on 7"<<endl;
  ofs_sbp<<"ls 2 on 3"<<endl;
  ofs_sbp<<"ls 2 on 4"<<endl;
  ofs_sbp<<"ls 2 on 5"<<endl;



  ofs_sbp<<"!LAB  POS Y  4.00"<<endl;
  ofs_sbp<<"!LAB  ROT"<<endl;
  ofs_sbp<<"win 1"<<endl;
  ofs_sbp<<"yplot 1 2 3 4 5"<<endl;
  ofs_sbp<<"loc 0 0 1 1"<<endl;
  ofs_sbp<<"vie .1 .4 .9 .9"<<endl;
  ofs_sbp<<"la y cnt/s/pixel/cm^2"<<endl;
  ofs_sbp<<"log x"<<endl;
  ofs_sbp<<"log y"<<endl;
  ofs_sbp<<"r x "<<(radii[1]+radii[0])/2*cm_per_pixel/kpc<<" "<<(radii[sbps.size()-2]+radii[sbps.size()-1])/2*cm_per_pixel/kpc<<endl;
  ofs_sbp<<"win 2"<<endl;
  ofs_sbp<<"yplot 6 7"<<endl;
  ofs_sbp<<"loc 0 0 1 1"<<endl;
  ofs_sbp<<"vie .1 .1 .9 .4"<<endl;
  ofs_sbp<<"la x radius (kpc)"<<endl;
  ofs_sbp<<"la y chi"<<endl;
  ofs_sbp<<"log x"<<endl;
  ofs_sbp<<"log y off"<<endl;
  ofs_sbp<<"r x "<<(radii[1]+radii[0])/2*cm_per_pixel/kpc<<" "<<(radii[sbps.size()-2]+radii[sbps.size()-1])/2*cm_per_pixel/kpc<<endl;
  for(int i=1;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      double y=sbps[i-1];
      double ye=sbpe[i-1];
      double ym=mv[i-1];
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<y<<"\t"<<ye<<endl;
    }
  ofs_sbp<<"no no no"<<endl;
  for(int i=1;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      double y=sbps[i-1];
      double ye=sbpe[i-1];
      double ym=mv[i-1];
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<ym<<"\t"<<0<<endl;
    }
  //bkg
  ofs_sbp<<"no no no"<<endl;
  double bkg_level=abs(f.get_param_value("bkg"));
  for(int i=0;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<bkg_level<<"\t0"<<endl;
    }
  //rc1
  ofs_sbp<<"no no no"<<endl;
  double rc1_kpc=abs(f.get_param_value("rc1")*cm_per_pixel/kpc);
  double max_sbp=*max_element(sbps.begin(),sbps.end());
  double min_sbp=*min_element(sbps.begin(),sbps.end());
  for(double x=min_sbp;x<=max_sbp;x+=(max_sbp-min_sbp)/100)
    {
      ofs_sbp<<rc1_kpc<<"\t"<<x<<"\t"<<"0"<<endl;
    }
  //rc2
  ofs_sbp<<"no no no"<<endl;
  double rc2_kpc=abs(f.get_param_value("rc2")*cm_per_pixel/kpc);
  for(double x=min_sbp;x<=max_sbp;x+=(max_sbp-min_sbp)/100)
    {
      ofs_sbp<<rc2_kpc<<"\t"<<x<<"\t"<<"0"<<endl;
    }
  //resid
  ofs_sbp<<"no no no"<<endl;
  for(int i=1;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      double y=sbps[i-1];
      double ye=sbpe[i-1];
      double ym=mv[i-1];
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<(ym-sbps[i-1])/sbpe[i-1]<<"\t"<<1<<endl;
    }
  //zero level in resid map
  ofs_sbp<<"no no no"<<endl;
  for(int i=1;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      double y=sbps[i-1];
      double ye=sbpe[i-1];
      double ym=mv[i-1];
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<0<<"\t"<<0<<endl;
    }


  mv=f.eval_model_raw(radii,p);
  ofstream ofs_rho("rho_fit.qdp");
  ofstream ofs_rho_data("rho_fit.dat");
  ofstream ofs_entropy("entropy.qdp");
  ofs_rho<<"la x radius (kpc)"<<endl;
  ofs_rho<<"la y density (cm\\u-3\\d)"<<endl;
  /*
  for(int i=1;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      double ym=mv[i-1];
      ofs_rho<<x*cm_per_pixel/kpc<<"\t"<<ym<<endl;
    }
  */

  double lower,upper;
  double dr=1;
  //calculate the mass profile
  const double G=6.673E-8;//cm^3 g^-1 s^-2
  // Molecular weight per electron
  // Reference: Ettori et al. 2013, Space Sci. Rev., 177, 119-154; Eq.(9) below
  static const double mu=1.155;
  static const double mp=1.67262158E-24;//g
  static const double M_sun=1.98892E33;//g
  static const double k=1.38E-16;

  ofstream ofs_mass("mass_int.qdp");
  ofstream ofs_mass_dat("mass_int.dat");
  ofstream ofs_overdensity("overdensity.qdp");
  ofstream ofs_gas_mass("gas_mass_int.qdp");
  //ofs_mass<<"la x radius (kpc)"<<endl;
  //ofs_mass<<"la y mass enclosed (solar mass)"<<endl;
  //ofs_overdensity<<"la x radius (kpc)"<<endl;
  //ofs_overdensity<<"la y overdensity"<<endl;
  double gas_mass=0;
  for(double r=1;r<200000;r+=dr)
    {
      dr=r/100;
      double r1=r+dr;
      double r_cm=r*cm_per_pixel;
      double r1_cm=r1*cm_per_pixel;
      double dr_cm=dr*cm_per_pixel;
      double V_cm3=4./3.*pi*(dr_cm*(r1_cm*r1_cm+r_cm*r_cm+r_cm*r1_cm));
      double ne=dbeta_func(r,n01,rc1,beta1,
			   n02,rc2,beta2);//cm^3

      double dmgas=V_cm3*ne*mu*mp/M_sun;
      gas_mass+=dmgas;

      ofs_gas_mass<<r*cm_per_pixel/kpc<<"\t"<<gas_mass<<endl;
      double ne_beta1=dbeta_func(r,n01,rc1,beta1,
				 0,rc2,beta2);

      double ne_beta2=dbeta_func(r,0,rc1,beta1,
				 n02,rc2,beta2);

      double ne1=dbeta_func(r1,n01,rc1,beta1,
			    n02,rc2,beta2);//cm^3

      double T_keV=Tprof(r);
      double T1_keV=Tprof(r1);

      double T_K=T_keV*11604505.9;
      double T1_K=T1_keV*11604505.9;

      double dlnT=log(T1_keV/T_keV);
      double dlnr=log(r+dr)-log(r);
      double dlnn=log(ne1/ne);

      double r_kpc=r_cm/kpc;
      double r_Mpc=r_cm/Mpc;
      //double M=-r_cm*T_K*k/G/mu/mp*(dlnT/dlnr+dlnn/dlnr);
      //ref:http://adsabs.harvard.edu/abs/2012MNRAS.422.3503W
      //Walker et al. 2012
      double M=-3.68E13*M_sun*T_keV*r_Mpc*(dlnT/dlnr+dlnn/dlnr);
      double rho=M/(4./3.*pi*r_cm*r_cm*r_cm);

      double S=T_keV/pow(ne,2./3.);
      //cout<<r<<"\t"<<M/M_sun<<endl;
      //cout<<r<<"\t"<<T_keV<<endl;

      ofs_rho<<r*cm_per_pixel/kpc<<"\t"<<ne<<"\t"<<ne_beta1<<"\t"<<ne_beta2<<endl;
      ofs_rho_data<<r*cm_per_pixel/kpc<<"\t"<<ne<<endl;
      ofs_entropy<<r*cm_per_pixel/kpc<<"\t"<<S<<endl;
#if 0
      if(r*cm_per_pixel/kpc<5)
	{
	  continue;
	}
#endif
      ofs_mass<<r*cm_per_pixel/kpc<<"\t"<<M/M_sun<<endl;
      if(r<radii.back())
	{
	  ofs_mass_dat<<r*cm_per_pixel/kpc<<"\t0\t"<<M/M_sun<<"\t"<<M/M_sun*.1<<endl;
	}
      ofs_overdensity<<r*cm_per_pixel/kpc<<"\t"<<rho/calc_critical_density(z)<<endl;

    }
}
