/**
 * Calculate the total luminosity and flux within the specified radius.
 *
 * Base on 'fit_dbeta_sbp.cpp' and supersede 'calc_lx.cpp'
 *
 * Author: Junhua Gu
 */

#include <iostream>
#include <fstream>
#include <sstream>
#include <list>
#include "vchisq.hpp"
#include "dbeta.hpp"
#include "beta_cfg.hpp"
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

double dbeta_func(double r, double n01, double rc1, double beta1,
                  double n02, double rc2, double beta2)
{
  double v1 = abs(n01) * pow(1+r*r/rc1/rc1, -3./2.*abs(beta1));
  double v2 = abs(n02) * pow(1+r*r/rc2/rc2, -3./2.*abs(beta2));
  return v1 + v2;
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
  if(argc<4)
    {
      cerr<<argv[0]<<" <sbp.conf> <rout_kpc> <cfunc_erg> [cfunc2_erg ...]"<<endl;
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
	  break;
	}
      cf.add_point(x,y);
    }
  cf.gen_spline();

  //read temperature profile data
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
  /*
  double =0;
  double rc1=0;
  double n02=0;
  double rc2=0;
  double beta=0;
  */
  double bkg_level=0;

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

  /*
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
  */

  //output the params
  ofstream param_output("lx_dbeta_param.txt");
  //output the datasets and fitting results
  for(size_t i=0;i<f.get_num_params();++i)
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
  cerr<<"reduced_chi^2="<<f.get_statistic_value()/(radii.size()-f.get_model().get_num_free_params())<<endl;
  param_output<<"reduced_chi^2="<<f.get_statistic_value()/(radii.size()-f.get_model().get_num_free_params())<<endl;

  //c.verbose(false);
  //f.set_statistic(c);
  //f.fit();
  std::vector<double> p=f.get_all_params();
  f.clear_param_modifier();
  std::vector<double> mv=f.eval_model(radii,p);


  ofstream ofs_sbp("lx_sbp_fit.qdp");
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
  ofs_sbp<<"la y cnt/s/pixel/cm\\u2\\d"<<endl;
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
  for(size_t i=1;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      double y=sbps[i-1];
      double ye=sbpe[i-1];
      //double ym=mv[i-1];
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<y<<"\t"<<ye<<endl;
    }
  ofs_sbp<<"no no no"<<endl;
  for(size_t i=1;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      //double y=sbps[i-1];
      //double ye=sbpe[i-1];
      double ym=mv[i-1];
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<ym<<"\t"<<0<<endl;
    }
  //bkg
  ofs_sbp<<"no no no"<<endl;
  bkg_level=abs(f.get_param_value("bkg"));
  for(size_t i=0;i<sbps.size();++i)
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
  for(size_t i=1;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      //double y=sbps[i-1];
      //double ye=sbpe[i-1];
      double ym=mv[i-1];
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<(ym-sbps[i-1])/sbpe[i-1]<<"\t"<<1<<endl;
    }
  //zero level in resid map
  ofs_sbp<<"no no no"<<endl;
  for(size_t i=1;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      //double y=sbps[i-1];
      //double ye=sbpe[i-1];
      //double ym=mv[i-1];
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<0<<"\t"<<0<<endl;
    }


  mv=f.eval_model_raw(radii,p);
  ofstream ofs_rho("lx_rho_fit.qdp");
  ofstream ofs_rho_data("lx_rho_fit.dat");
  //ofstream ofs_entropy("entropy.qdp");
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

  p.back()=0;

  radii.clear();
  double rout=atof(argv[2])*kpc;
  for(double r=0;r<rout;r+=1*kpc)//step size=1kpc
    {
      double r_pix=r/cm_per_pixel;
      radii.push_back(r_pix);
    }

  double Da=cm_per_pixel/(.492/3600./180.*pi);
  double Dl=Da*(1+z)*(1+z);
  cout<<"dl="<<Dl/kpc<<endl;
  for(int n=3;n<argc;++n)
    {
      spline_func_obj cf_erg;
      for(ifstream ifs(argv[n]);;)
	{
	  assert(ifs.is_open());
	  double x,y;
	  ifs>>x>>y;
	  if(!ifs.good())
	    {
	      break;
	    }
	  //cerr<<x<<"\t"<<y<<endl;

	  cf_erg.add_point(x,y);//change with source
	}
      cf_erg.gen_spline();

      projector<double>& pj=dynamic_cast<projector<double>&>(f.get_model());
      pj.attach_cfunc(cf_erg);

      mv=f.eval_model_raw(radii,p);
      double flux_erg=0;
      for(size_t i=0;i<radii.size()-1;++i)
	{
	  double S=pi*(radii[i+1]+radii[i])*(radii[i+1]-radii[i]);
	  flux_erg+=S*mv[i];
	}
      cout<<flux_erg*4*pi*Dl*Dl<<endl;
      cout<<flux_erg<<endl;
      param_output<<"Lx"<<n-2<<"\t"<<flux_erg*4*pi*Dl*Dl<<endl;
      param_output<<"Fx"<<n-2<<"\t"<<flux_erg<<endl;
    }
}
