/*
  Perform a double-beta density model fitting to the surface brightness data
  Author: Junhua Gu
  Last modified: 2016.06.07
  This code is distributed with no warrant
*/

#include <iostream>
#include <fstream>
#include <sstream>
#include <list>
#include <algorithm>
#include "beta_cfg.hpp"
#include "dump_fit_qdp.hpp"
#include "report_error.hpp"
#include "vchisq.hpp"
#include "chisq.hpp"
#include "beta.hpp"
#include "models/beta1d.hpp"
#include <data_sets/default_data_set.hpp>
#include <methods/powell/powell_method.hpp>
#include <core/freeze_param.hpp>
#include <error_estimator/error_estimator.hpp>
#include "spline.hpp"

using namespace std;
using namespace opt_utilities;
//double s=5.63136645E20;
const double kpc=3.086E21;//kpc in cm
const double Mpc=kpc*1000;

double beta_func(double r, double n0, double rc, double beta)
{
  return abs(n0) * pow(1+r*r/rc/rc, -3./2.*abs(beta));
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


//A class enclosing the spline interpolation method
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

  const double z=cfg.z;

  //initialize the radius list, sbp list and sbp error list
  std::vector<double> radii;
  std::vector<double> sbps;
  std::vector<double> sbpe;
  std::vector<double> radii_all;
  std::vector<double> sbps_all;
  std::vector<double> sbpe_all;
  //prepend the zero point to radius list
  radii.push_back(0.0);
  radii_all.push_back(0.0);
  //read sbp and sbp error data
  cerr << "Read surface brightness profile data ..." << endl;
  ifstream ifs(cfg.sbp_data.c_str());
  std::string line;
  if (ifs.is_open())
    {
      while(std::getline(ifs, line))
        {
          if (line.empty())
            continue;

          std::istringstream iss(line);
          double x, xe, y, ye;
          if ((iss >> x >> xe >> y >> ye))
            {
              std::cerr << "sbprofile data: "
                        << x << ", " << xe << ", " << y << ", " << ye
                        << std::endl;
              radii.push_back(x+xe);  /* NOTE: use outer radii of regions */
              radii_all.push_back(x+xe);
              sbps.push_back(y);
              sbps_all.push_back(y);
              sbpe.push_back(ye);
              sbpe_all.push_back(ye);
            }
          else
            {
              std::cerr << "skipped line: " << line << std::endl;
            }
        }
    }
  else
    {
      std::cerr << "ERROR: cannot open file: " << cfg.sbp_data.c_str()
                << std::endl;
      return 1;
    }

  //initialize the cm/pixel value
  double cm_per_pixel=cfg.cm_per_pixel;
  double rmin;
  if(cfg.rmin_pixel>0)
    {
      rmin=cfg.rmin_pixel;
    }
  else
    {
      rmin=cfg.rmin_kpc*kpc/cm_per_pixel;
    }

  cerr<<"rmin="<<rmin<<" (pixel)"<<endl;
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
  cerr << "Read cooling function profile data ..." << endl;
  spline_func_obj cf;
  for(ifstream ifs(cfg.cfunc_profile.c_str());;)
    {
      assert(ifs.is_open());
      double x,y;
      ifs>>x>>y;
      if(!ifs.good())
	{
	  break;
	}
      cerr<<x<<"\t"<<y<<endl;
      if(x>radii.back())
	{
      cerr << "radius_max: " << radii.back() << endl;
	  break;
	}
      cf.add_point(x,y);
    }
  cf.gen_spline();

  //read temperature profile data
  cerr << "Read temperature profile data ..." << endl;
  spline_func_obj Tprof;
  int tcnt=0;
  for(ifstream ifs1(cfg.tprofile.c_str());;++tcnt)
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
  beta<double> betao;
  //attach the cooling function
  a.attach_cfunc(cf);
  a.set_cm_per_pixel(cm_per_pixel);
  a.attach_model(betao);
  f.set_model(a);
  //chi^2 statistic
  vchisq<double> c;
  c.verbose(true);
  c.set_limit();
  f.set_statistic(c);
  //optimization method
  f.set_opt_method(powell_method<double,std::vector<double> >());
  //initialize the initial values
  double n0=0;
  //double beta=atof(arg_map["beta"].c_str());
  double beta=0;
  double rc=0;
  double bkg_level=0;

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
	  if(pname=="beta")
	    {
	      f.set_param_lower_limit(pname,.3);
	      f.set_param_upper_limit(pname,1.4);
	    }
	}
    }

  f.fit();
  f.fit();
  std::vector<double> p=f.get_all_params();
  n0=f.get_param_value("n0");
  rc=f.get_param_value("rc");
  beta=f.get_param_value("beta");
  //output the datasets and fitting results
  ofstream param_output("beta_param.txt");
  for(size_t i=0;i<f.get_num_params();++i)
    {
      if(f.get_param_info(i).get_name()=="rc")
	{
	  cerr<<"rc_kpc"<<"\t"<<abs(f.get_param_info(i).get_value())*cm_per_pixel/kpc<<endl;
	  param_output<<"rc_kpc"<<"\t"<<abs(f.get_param_info(i).get_value())*cm_per_pixel/kpc<<endl;
	}
      cerr<<f.get_param_info(i).get_name()<<"\t"<<abs(f.get_param_info(i).get_value())<<endl;
      param_output<<f.get_param_info(i).get_name()<<"\t"<<abs(f.get_param_info(i).get_value())<<endl;
    }
  cerr<<"reduced_chi^2="<<f.get_statistic_value()/(radii.size()-f.get_model().get_num_free_params())<<endl;
  param_output<<"reduced_chi^2="<<f.get_statistic_value()/(radii.size()-f.get_model().get_num_free_params())<<endl;

  std::vector<double> mv=f.eval_model_raw(radii_all,p);
  int sbps_inner_cut_size=int(sbps_all.size()-sbps.size());
  ofstream ofs_sbp("sbp_fit.qdp");
  ofs_sbp<<"read serr 2"<<endl;
  ofs_sbp<<"skip single"<<endl;
  ofs_sbp<<"line off "<<endl;
  if(sbps_inner_cut_size>=1)
    {
      ofs_sbp<<"line on 2"<<endl;
      ofs_sbp<<"line on 3"<<endl;
      ofs_sbp<<"line on 4"<<endl;
      ofs_sbp<<"line on 5"<<endl;
      ofs_sbp<<"ls 2 on 2"<<endl;
      ofs_sbp<<"ls 2 on 4"<<endl;
      ofs_sbp<<"ls 2 on 5"<<endl;
      ofs_sbp<<"line on 7"<<endl;
      ofs_sbp<<"ls 2 on 7"<<endl;

      ofs_sbp<<"ma 1 on 2"<<endl;
      ofs_sbp<<"color 1 on 1"<<endl;
      ofs_sbp<<"color 2 on 2"<<endl;
      ofs_sbp<<"color 3 on 3"<<endl;
      ofs_sbp<<"color 4 on 4"<<endl;
      ofs_sbp<<"color 5 on 5"<<endl;

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
      ofs_sbp<<"log y off"<<endl;
      ofs_sbp<<"log x"<<endl;
      ofs_sbp<<"r x "<<(radii[1]+radii[0])/2*cm_per_pixel/kpc<<" "<<(radii[sbps.size()-2]+radii[sbps.size()-1])/2*cm_per_pixel/kpc<<endl;
    }
  else
    {
      ofs_sbp<<"line on 2"<<endl;
      ofs_sbp<<"line on 3"<<endl;
      ofs_sbp<<"line on 4"<<endl;
      ofs_sbp<<"ls 2 on 3"<<endl;
      ofs_sbp<<"ls 2 on 4"<<endl;
      ofs_sbp<<"line on 6"<<endl;
      ofs_sbp<<"ls 2 on 6"<<endl;

      ofs_sbp<<"color 1 on 1"<<endl;
      ofs_sbp<<"color 3 on 2"<<endl;
      ofs_sbp<<"color 4 on 3"<<endl;
      ofs_sbp<<"color 5 on 4"<<endl;
      //ofs_sbp<<"ma 1 on 2"<<endl;

      ofs_sbp<<"win 1"<<endl;
      ofs_sbp<<"yplot 1 2 3 4"<<endl;
      ofs_sbp<<"loc 0 0 1 1"<<endl;
      ofs_sbp<<"vie .1 .4 .9 .9"<<endl;
      ofs_sbp<<"la y cnt/s/pixel/cm^2"<<endl;
      ofs_sbp<<"log x"<<endl;
      ofs_sbp<<"log y"<<endl;
      ofs_sbp<<"r x "<<(radii[1]+radii[0])/2*cm_per_pixel/kpc<<" "<<(radii[radii.size()-2]+radii[radii.size()-1])/2*cm_per_pixel/kpc<<endl;
      ofs_sbp<<"win 2"<<endl;
      ofs_sbp<<"yplot 5 6"<<endl;
      ofs_sbp<<"loc 0 0 1 1"<<endl;
      ofs_sbp<<"vie .1 .1 .9 .4"<<endl;
      ofs_sbp<<"la x radius (kpc)"<<endl;
      ofs_sbp<<"la y chi"<<endl;
      ofs_sbp<<"log x"<<endl;
      ofs_sbp<<"log y off"<<endl;
      ofs_sbp<<"r x "<<(radii[1]+radii[0])/2*cm_per_pixel/kpc<<" "<<(radii[radii.size()-2]+radii[radii.size()-1])/2*cm_per_pixel/kpc<<endl;

    }
  // cout<<sbps_all.size()<<"\t"<<sbps.size()<<"\t"<<sbps_inner_cut_size<<endl;
  for(size_t i=1;i<sbps_all.size();++i)
    {
      double x=(radii_all[i]+radii_all[i-1])/2;
      double y=sbps_all[i-1];
      double ye=sbpe_all[i-1];
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<y<<"\t"<<ye<<endl;
    }
  if(sbps_inner_cut_size>=1)
    {
      ofs_sbp<<"no no no"<<endl;
      for(int i=1;i<sbps_inner_cut_size+1;++i)
	{
	  double x=(radii_all[i]+radii_all[i-1])/2;
	  double ym=mv[i-1];
	  ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<ym<<"\t"<<"0"<<endl;
	}
    }
  ofs_sbp<<"no no no"<<endl;
  for(size_t i=sbps_inner_cut_size;i<sbps_all.size();++i)
    {
      double x=(radii_all[i]+radii_all[i-1])/2;
      double ym=mv[i-1];
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<ym<<"\t"<<"0"<<endl;
    }
  ofs_sbp<<"no no no"<<endl;
  //bkg level
  bkg_level=abs(f.get_param_value("bkg"));
  for(size_t i=0;i<sbps_all.size();++i)
    {
      double x=(radii_all[i]+radii_all[i-1])/2;
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<bkg_level<<"\t0"<<endl;
    }
  ofs_sbp<<"no no no"<<endl;
  //rc
  double rc_kpc=abs(f.get_param_value("rc")*cm_per_pixel/kpc);
  double max_sbp=*max_element(sbps_all.begin(),sbps_all.end());
  double min_sbp=*min_element(sbps_all.begin(),sbps_all.end());
  for(double x=min_sbp;x<=max_sbp;x+=(max_sbp-min_sbp)/100)
    {
      ofs_sbp<<rc_kpc<<"\t"<<x<<"\t"<<"0"<<endl;
    }
  //resid
  ofs_sbp<<"no no no"<<endl;
  for(size_t i=1;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      //double y=sbps[i-1];
      //double ye=sbpe[i-1];
      double ym=mv[i-1];
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<(ym-sbps[i-1])/sbpe[i-1]<<"\t"<<1<<endl;
    }

  //zero level of resid
  ofs_sbp<<"no no no"<<endl;
  for(size_t i=1;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      //double y=sbps[i-1];
      //double ye=sbpe[i-1];
      //double ym=mv[i-1];
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<0<<"\t"<<0<<endl;
    }

  mv=betao.eval(radii,p);
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

  //double lower,upper;
  double dr=1;
  //calculate the mass profile
  //const double G=6.673E-8;//cm^3 g^-1 s^-2
  // Molecular weight per electron
  // Reference: Ettori et al. 2013, Space Sci. Rev., 177, 119-154; Eq.(9) below
  static const double mu=1.155;
  static const double mp=1.67262158E-24;//g
  static const double M_sun=1.98892E33;//g
  //static const double k=1.38E-16;

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
      double ne=beta_func(r,n0,rc,beta);//cm^-3

      double dmgas=V_cm3*ne*mu*mp/M_sun;
      gas_mass+=dmgas;

      ofs_gas_mass<<r*cm_per_pixel/kpc<<"\t"<<gas_mass<<endl;
      double ne1=beta_func(r1,n0,rc,beta);//cm^3

      double T_keV=Tprof(r);
      double T1_keV=Tprof(r1);

      //double T_K=T_keV*11604505.9;
      //double T1_K=T1_keV*11604505.9;

      double dlnT=log(T1_keV/T_keV);
      double dlnr=log(r+dr)-log(r);
      double dlnn=log(ne1/ne);

      //double r_kpc=r_cm/kpc;
      double r_Mpc=r_cm/Mpc;
      //double M=-r_cm*T_K*k/G/mu/mp*(dlnT/dlnr+dlnn/dlnr);
      //ref:http://adsabs.harvard.edu/abs/2012MNRAS.422.3503W
      //Walker et al. 2012
      double M=-3.68E13*M_sun*T_keV*r_Mpc*(dlnT/dlnr+dlnn/dlnr);
      double rho=M/(4./3.*pi*r_cm*r_cm*r_cm);

      double S=T_keV/pow(ne,2./3.);
      //cout<<r<<"\t"<<M/M_sun<<endl;
      //cout<<r<<"\t"<<T_keV<<endl;

      ofs_rho<<r*cm_per_pixel/kpc<<"\t"<<ne<<endl;
      ofs_rho_data<<r*cm_per_pixel/kpc<<"\t"<<ne<<endl;
      ofs_entropy<<r*cm_per_pixel/kpc<<"\t"<<S<<endl;
#if 0
      if(r*cm_per_pixel/kpc<5)
	{
	  continue;
	}
#endif
      ofs_mass<<r*cm_per_pixel/kpc<<"\t"<<M/M_sun<<endl;
      if(r<radii.at(sbps.size()))
	{
	  ofs_mass_dat<<r*cm_per_pixel/kpc<<"\t0\t"<<M/M_sun<<"\t"<<M/M_sun*.1<<endl;
	}
      ofs_overdensity<<r*cm_per_pixel/kpc<<"\t"<<rho/calc_critical_density(z)<<endl;

    }
}
