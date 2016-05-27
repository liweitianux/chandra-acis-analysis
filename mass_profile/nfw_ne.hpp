/*
  Gas density profile derived from nfw mass profile and temperature profile
  Author: Junhua Gu
  Last modification: 20120721
*/

#ifndef NFW_NE
#define NFW_NE
#include "projector.hpp"
#include <algorithm>
#include <functional>
#include <numeric>

//a series of physical constants
static const double G=6.673E-8;//cm^3 g^-1 s^2
static const double mu=1.4074;
static const double mp=1.67262158E-24;//g
static const double k=1.60217646E-9;//erg/keV
static const double c=2.99792458E10;//cm/s


namespace opt_utilities
{
  //the nfw mass enclosed within a radius r, with parameter rho0 and rs
  template <typename T>
  T nfw_mass_enclosed(T r,T rho0,T rs)
  {
    return 4*pi*rho0*rs*rs*rs*(std::log((r+rs)/rs)-r/(r+rs));
  }

  //average mass density
  template <typename T>
  T nfw_average_density(T r,T rho0,T rs)
  {
    if(r==0)
      {
	return rho0;
      }
    
    return nfw_mass_enclosed(r,rho0,rs)/(4.*pi/3*r*r*r);
  }

  //calculate critical density from z, under following cosmological constants
  static double calc_critical_density(double z,
				      const double H0=2.3E-18,
				      const double Omega_m=.27)
  {
    const double E=std::sqrt(Omega_m*(1+z)*(1+z)*(1+z)+1-Omega_m);
    const double H=H0*E;    
    return 3*H*H/8/pi/G;
  }


  //a class wraps method of calculating gas density from mass profile and temperature profile
  template <typename T>
  class nfw_ne
    :public model<std::vector<T>,std::vector<T>,std::vector<T> >
  {
  private:
    //pointer to temperature profile function
    func_obj<T,T>* pTfunc;
    //cm per pixel
    T cm_per_pixel;
  public:
    //default constructor
    nfw_ne()
      :pTfunc(0),cm_per_pixel(1)
    {
      
      this->push_param_info(param_info<std::vector<T>,std::string>("rho0",1));//in mp
      this->push_param_info(param_info<std::vector<T>,std::string>("rs",100));
      this->push_param_info(param_info<std::vector<T>,std::string>("n0",.01));
    }

    //copy constructor
    nfw_ne(const nfw_ne& rhs)
      :cm_per_pixel(rhs.cm_per_pixel)
    {
      if(rhs.pTfunc)
	{
	  pTfunc=rhs.pTfunc->clone();
	}
      else
	{
	  pTfunc=0;
	}
      //initial parameter list
      this->push_param_info(param_info<std::vector<T>,std::string>("rho0",rhs.get_param_info("rho0").get_value()));
      this->push_param_info(param_info<std::vector<T>,std::string>("rs",rhs.get_param_info("rs").get_value()));
      this->push_param_info(param_info<std::vector<T>,std::string>("n0",rhs.get_param_info("n0").get_value()));
    }
    
    //assignment operator
    nfw_ne& operator=(const nfw_ne& rhs)
    {
      cm_per_pixel=rhs.cm_per_pixel;
      if(pTfunc)
	{
	  pTfunc->destroy();
	}
      if(rhs.pTfunc)
	{
	  pTfunc=rhs.pTfunc->clone();
	}
    }

    //destructor
    ~nfw_ne()
    {
      if(pTfunc)
	{
	  pTfunc->destroy();
	}
    }

  public:
    //attach the temperature profile function
    void attach_Tfunc(const func_obj<T,T>& Tf)
    {
      if(pTfunc)
	{
	  pTfunc->destroy();
	}
      pTfunc=Tf.clone();
    }

    //set the cm per pixel value
    void set_cm_per_pixel(const T& x)
    {
      cm_per_pixel=x;
    }

    //clone self
    nfw_ne<T>* do_clone()const
    {
      return new nfw_ne<T>(*this);
    }


    //calculate density under parameters p, at radius r
    /*
      r is a vector, which stores a series of radius values
      the annuli or pie regions are enclosed between any two
      adjacent radii.
      so the returned value has length smaller than r by 1.
     */
    std::vector<T> do_eval(const std::vector<T> & r,
			   const std::vector<T>& p)
    {						
      assert(pTfunc);
      //const T kT_erg=k*5;
      T rho0=std::abs(p[0])*mp;
      T rs=std::abs(p[1]);
      T n0=std::abs(p[2]);
      T rs_cm=rs*cm_per_pixel;
      
      std::vector<T> yvec(r.size());
      const T kT_erg0=pTfunc->eval((r.at(0)+r.at(1))/2)*k;
      //calculate the integration
#pragma omp parallel for schedule(dynamic)
      for(int i=0;i<r.size();++i)
	{
	  T r_cm=r[i]*cm_per_pixel;
	  T kT_erg=pTfunc->eval(r[i])*k;
	  if(abs(r_cm)==0)
	    {
	      continue;
	    }
	  yvec.at(i)=G*nfw_mass_enclosed(r_cm,rho0,rs_cm)*mu*mp/kT_erg/r_cm/r_cm;
	  //std::cout<<r_cm/1e20<<"\t"<<nfw_mass_enclosed(r_cm,rho0,rs_cm)/1e45<<std::endl;
	  //std::cout<<r_cm/1e20<<"\t"<<G*nfw_mass_enclosed(r_cm,rho0,rs_cm)*mu*mp/kT_erg/r_cm/r_cm<<std::endl;
	}
      
      std::vector<T> ydxvec(r.size()-1);
#pragma omp parallel for schedule(dynamic)
      for(int i=1;i<r.size();++i)
	{
	  T dr=r[i]-r[i-1];
	  T dr_cm=dr*cm_per_pixel;
	  ydxvec.at(i-1)=(yvec[i]+yvec[i-1])/2*dr_cm;
	}
      std::partial_sum(ydxvec.begin(),ydxvec.end(),ydxvec.begin());
      //construct the result
      std::vector<T> result(r.size()-1);
#pragma omp parallel for schedule(dynamic)
      for(int i=0;i<r.size()-1;++i)
	{
	  T y=-ydxvec.at(i);
	  T kT_erg=pTfunc->eval(r[i])*k;
	  //std::cout<<y<<std::endl;
	  result.at(i)=n0*exp(y)*kT_erg0/kT_erg;
	}
      return result;
    }
  };
}

#endif
