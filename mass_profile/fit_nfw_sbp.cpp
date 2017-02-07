/*
  Fitting the surface brightness profile with an NFW-based surface brightness model
  Author: Junhua Gu
  Last modification 20120721
  The temperature is assumed to be an allen model with a minimum temperature assumed
*/


#include <iostream>
#include <fstream>
#include "vchisq.hpp"
#include "nfw_ne.hpp"
#include <data_sets/default_data_set.hpp>
#include <methods/powell/powell_method.hpp>
#include <core/freeze_param.hpp>
#include <error_estimator/error_estimator.hpp>
#include "spline.hpp"
#include <cpgplot.h>
using namespace std;
using namespace opt_utilities;
//double s=5.63136645E20;
const double M_sun=1.988E33;//solar mass in g
const double kpc=3.086E21;//kpc in cm

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
    /*
    if(x<=spl.x_list[0])
      {
	return spl.y_list[0];
      }
    if(x>=spl.x_list.back())
      {
	return spl.y_list.back();
      }
    */
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

//Allen temperature model

int main(int argc,char* argv[])
{
  if(argc!=2)
    {
      cerr<<argv[0]<<" <configure file>"<<endl;
      cerr<<"Here is a sample of the configure file"<<endl;
      cerr<<"radius_file	radius1.dat\n"
	"sbp_file\tsbp1.dat\n"
	"cfunc_file\tcfunc.dat\n"
	"n0\t\t.04\n"
	"rs\t\t816\n"
	"rho0\t\t.01\n"
	"bkg\t\t0\n"
	"cm_per_pixel\t1.804E21\n"
	"z\t\t0.062476\n"
	"T_file\t\tT.dat"
	<<endl;
      cerr<<"Notes:"<<endl;
      cerr<<"n0 is in the unit of cm^-3"<<endl;
      cerr<<"rs is in the unit of pixel"<<endl;
      cerr<<"rho0 is in the unit of mass of proton per cm^3"<<endl;

      return -1;
    }
  //define a map to store the parameters
  std::map<std::string,std::string> arg_map;
  //open the configuration file
  ifstream cfg_file(argv[1]);
  assert(cfg_file.is_open());
  for(;;)
    {
      std::string key;
      std::string value;
      cfg_file>>key>>value;
      if(!cfg_file.good())
	{
	  cfg_file.close();
	  break;
	}
      arg_map[key]=value;
    }
  //check whether following parameters are defined in the configuration file
  assert(arg_map.find("radius_file")!=arg_map.end());
  assert(arg_map.find("sbp_file")!=arg_map.end());
  assert(arg_map.find("cfunc_file")!=arg_map.end());
  assert(arg_map.find("T_file")!=arg_map.end());
  assert(arg_map.find("z")!=arg_map.end());
  const double z=atof(arg_map["z"].c_str());
  double r_min=0;
  if(arg_map.find("r_min")!=arg_map.end())
    {
      r_min=atof(arg_map["r_min"].c_str());
      cerr<<"r_min presents and its value is "<<r_min<<endl;
    }
  //note that in this program, the radius are not the central value of each annuli or pie region, but the boundaries.
  //for example, if we have a set of radius and surface brightness values as follows:
  /*
    radius      width       surface brightness
    1           1           x
    2           1           x
    3           1           x

    then the radius is stored as
    0 1.5 2.5 3.5
    note that there should be 4 radius values, although only to represent 3 annuli.
    this will be convenient to calculate the volume of each spherical shell,
    and can naturally ensure the annuli are adjacent with each other, with out any gaps.


   */

  std::vector<double> radii;//to store radius
  std::vector<double> sbps;//to store the surface brightness value
  std::vector<double> sbpe;//to store the sbp error
  //read in radius file
  /*
    About the format of the radius file:
    the radius file contains only radius, separated by space or line feed (i.e., the <ENTER> key).
    the unit should be pixel

    The number of radius can be larger than the number of annuli+1, the exceeded radius can be used
    to calculate the influence of outer shells.
   */
  int ncut=0;
  for(ifstream ifs(arg_map["radius_file"].c_str());;)
    {
      assert(ifs.is_open());
      double x;
      ifs>>x;
      if(!ifs.good())
	{
	  break;
	}
      if(x<r_min)
	{
	  ++ncut;
	  continue;
	}
      cerr<<x<<endl;
      radii.push_back(x);
    }
  //read in surface brightness file
  /*
    the surface brightness file contains two columns, that are surface brightness and the error, respectively.
   */
  for(ifstream ifs(arg_map["sbp_file"].c_str());;)
    {
      assert(ifs.is_open());
      double x,xe;
      ifs>>x>>xe;
      if(!ifs.good())
	{
	  break;
	}
      if(ncut)
	{
	  --ncut;
	  continue;
	}
      cerr<<x<<"\t"<<xe<<endl;
      sbps.push_back(x);
      sbpe.push_back(xe);
    }
  //cerr<<radii.size()<<"\t"<<sbps.size()<<endl;
  //return 0;
  spline_func_obj cf;

  //read in the cooling function file
  /*
    the cooling function file contains two columns, that are radius (central value, in pixel) and the ``reduced cooling function''
    the reduced cooling function is calculated as follows
    by using wabs*apec model, fill the kT, z, nH to the actual value (derived from deproject spectral fitting),
    and fill norm as 1E-14/(4*pi*(Da*(1+z))^2).
    then use flux e1 e2 (e1 and e2 are the energy limits of the surface brightness profile) to get the cooling function (in photon counts,
    not in erg/s)
   */
  for(ifstream ifs(arg_map["cfunc_file"].c_str());;)
    {
      assert(ifs.is_open());
      double x,y;
      ifs>>x>>y;
      if(!ifs.good())
	{
	  break;
	}
      cerr<<x<<"\t"<<y<<endl;
      //cf.add_point(x,y*2.1249719395939022e-68);//change with source
      cf.add_point(x,y);//change with source
    }
  cf.gen_spline();

  for(double x=0;x<1000;x++)
    {
      //cout<<x<<"\t"<<cf(x)<<endl;
    }
  //return 0;
  //cout<<radii.size()<<endl;
  //cout<<sbps.size()<<endl;

  //initial a data set object and put the data together
  default_data_set<std::vector<double>,std::vector<double> > ds;
  ds.add_data(data<std::vector<double>,std::vector<double> >(radii,sbps,sbpe,sbpe,radii,radii));

  //initial a fitter object
  fitter<vector<double>,vector<double>,vector<double>,double> f;
  //load the data set into the fitter object
  f.load_data(ds);
  //define a projector object
  //see projector for more detailed information
  projector<double> a;
  //define the nfw surface brightness profofile model
  nfw_ne<double> nfw;
  //attach the cooling function into the projector
  a.attach_cfunc(cf);
  assert(arg_map.find("cm_per_pixel")!=arg_map.end());
  //set the cm to pixel ratio
  double cm_per_pixel=atof(arg_map["cm_per_pixel"].c_str());
  a.set_cm_per_pixel(cm_per_pixel);
  nfw.set_cm_per_pixel(cm_per_pixel);
  //define the temperature profile model
  spline_func_obj tf;

  for(ifstream ifs_tfunc(arg_map["T_file"].c_str());;)
    {
      assert(ifs_tfunc.is_open());
      double x,y;
      ifs_tfunc>>x>>y;
      if(!ifs_tfunc.good())
	{
	  break;
	}
      if(x<r_min)
	{
	  continue;
	}
      tf.add_point(x,y);
    }
  tf.gen_spline();

  //attach the temperature, surface brightness model and projector together
  nfw.attach_Tfunc(tf);
  a.attach_model(nfw);
  f.set_model(a);
  //define the chi-square statistic
  vchisq<double> c;
  c.verbose(true);
  f.set_statistic(c);
  //set the optimization method, here we use powell method
  f.set_opt_method(powell_method<double,std::vector<double> >());
  //set the initial values
  double n0=atof(arg_map["n0"].c_str());
  double rho0=atof(arg_map["rho0"].c_str());
  double rs=atof(arg_map["rs"].c_str());
  double bkg=atof(arg_map["bkg"].c_str());
  f.set_param_value("n0",n0);
  f.set_param_value("rho0",rho0);
  f.set_param_value("rs",rs);


  f.set_param_value("bkg",bkg);

  cout<<f.get_data_set().size()<<endl;
  cout<<f.get_num_params()<<endl;
#if 1
  //perform the fitting
  f.fit();
  f.set_precision(1e-10);
  f.fit();
  f.clear_param_modifier();
  f.fit();
#endif
  //output the parameters
  ofstream param_output("nfw_param.txt");

  for(size_t i=0;i<f.get_num_params();++i)
    {
      cout<<f.get_param_info(i).get_name()<<"\t"<<abs(f.get_param_info(i).get_value())<<endl;
      param_output<<f.get_param_info(i).get_name()<<"\t"<<abs(f.get_param_info(i).get_value())<<endl;
    }
  c.verbose(false);
  f.set_statistic(c);
#if 1
  f.fit();
  f.fit();
#endif
  //fetch the fitting result
  std::vector<double> p=f.get_all_params();
  f.clear_param_modifier();
  std::vector<double> mv=f.eval_model(radii,p);
  cerr<<mv.size()<<endl;
  //output the results
  ofstream ofs_sbp("sbp_fit.qdp");
  ofstream ofs_resid("resid.qdp");
  ofs_resid<<"read serr 2"<<endl;
  //output the surface brightness profile
  ofs_sbp<<"read serr 2"<<endl;
  ofs_sbp<<"skip single"<<endl;
  for(size_t i=1;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      double y=sbps[i-1];
      double ye=sbpe[i-1];
      double ym=mv[i-1];
      ofs_sbp<<x*cm_per_pixel/kpc<<"\t"<<y<<"\t"<<ye<<"\t"<<ym<<endl;
      ofs_resid<<x*cm_per_pixel/kpc<<"\t"<<(y-ym)/ye<<"\t1\n";
    }
  //output the electron density
  mv=nfw.eval(radii,p);
  ofstream ofs_rho("rho_fit.qdp");
  for(size_t i=1;i<sbps.size();++i)
    {
      double x=(radii[i]+radii[i-1])/2;
      double ym=mv[i-1];
      ofs_rho<<x*cm_per_pixel/kpc<<"\t"<<ym<<endl;
    }
  //output integral mass profile
  rho0=f.get_param_value("rho0")*1.67E-24;
  rs=f.get_param_value("rs")*cm_per_pixel;
  ofstream ofs_int_mass("mass_int.qdp");
  for(double r=0;r<2000*kpc;r+=kpc)
    {
      ofs_int_mass<<r/kpc<<"\t"<<nfw_mass_enclosed(r,abs(rho0),abs(rs))/M_sun<<endl;
    }
  //calculate the overdensity profile
  ofstream ofs_overdensity("overdensity.qdp");

  std::vector<double> radius_list;
  std::vector<double> delta_list;

  cerr<<"delta\tr_delta (kpc)\tr_delta (pixel)\tmass_delta (solar mass)\n";
  for(double r=kpc;r<6000*kpc;r+=kpc)
    {
      double delta=nfw_average_density(r,abs(rho0),abs(rs))/calc_critical_density(z);
      radius_list.push_back(r);
      delta_list.push_back(delta);

      /*
      if(delta<=200&&!hit_200)
	{
	  hit_200=true;
	  cerr<<200<<"\t"<<r/kpc<<"\t\t"<<r/cm_per_pixel<<"\t\t"<<nfw_mass_enclosed(r,abs(rho0),abs(rs))/M_sun<<endl;
	  break;
	}
      if(delta<=500&&!hit_500)
	{
	  hit_500=true;
	  cerr<<500<<"\t"<<r/kpc<<"\t\t"<<r/cm_per_pixel<<"\t\t"<<nfw_mass_enclosed(r,abs(rho0),abs(rs))/M_sun<<endl;
	}
      */
      ofs_overdensity<<r/kpc<<"\t"<<delta<<endl;
    }

  for(size_t i=0;i<radius_list.size()-1;++i)
    {
      double r=radius_list[i];
      if(delta_list[i]>=200&&delta_list[i+1]<200)
	{
	  cerr<<200<<"\t"<<r/kpc<<"\t\t"<<r/cm_per_pixel<<"\t\t"<<nfw_mass_enclosed(r,abs(rho0),abs(rs))/M_sun<<endl;
	}

      if(delta_list[i]>=500&&delta_list[i+1]<500)
	{
	  cerr<<500<<"\t"<<r/kpc<<"\t\t"<<r/cm_per_pixel<<"\t\t"<<nfw_mass_enclosed(r,abs(rho0),abs(rs))/M_sun<<endl;
	}

      if(delta_list[i]>=1500&&delta_list[i+1]<1500)
	{
	  cerr<<1500<<"\t"<<r/kpc<<"\t\t"<<r/cm_per_pixel<<"\t\t"<<nfw_mass_enclosed(r,abs(rho0),abs(rs))/M_sun<<endl;
	}

      if(delta_list[i]>=2500&&delta_list[i+1]<2500)
	{
	  cerr<<2500<<"\t"<<r/kpc<<"\t\t"<<r/cm_per_pixel<<"\t\t"<<nfw_mass_enclosed(r,abs(rho0),abs(rs))/M_sun<<endl;
	}

    }

  //output the M200 and R200
  //cerr<<"M200="<<nfw_mass_enclosed(r200,abs(rho0),abs(rs))/M_sun<<" solar mass"<<endl;
  //cerr<<"R200="<<r200/kpc<<" kpc"<<endl;
  //for(int i=0;i<p.size();++i)
  //{
  //cerr<<p[i]<<endl;
  //}
  return 0;
}
