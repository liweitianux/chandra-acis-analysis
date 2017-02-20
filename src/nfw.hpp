/**
   \file nfw.hpp
   \brief Jingying Wang's model
   \author Jingying Wang
 */


#ifndef NFW
#define NFW
#define OPT_HEADER
#include <core/fitter.hpp>
#include <cmath>

namespace opt_utilities
{
  template <typename T>
  class nfw
    :public model<T,T,std::vector<T>,std::string>
  {
  private:
    model<T,T,std::vector<T> >* do_clone()const
    {
      return new nfw<T>(*this);
    }

    const char* do_get_type_name()const
    {
      return "1d power law";
    }
  public:
    nfw()
    {
      this->push_param_info(param_info<std::vector<T> >("rho0",1,0,1e99));
      this->push_param_info(param_info<std::vector<T> >("rs",100,0,1e99));
    }

    T do_eval(const T& r,const std::vector<T>& param)
    {
      T rho0=std::abs(param[0]);
      T rs=std::abs(param[1]);
      static const T pi=4*std::atan(1);
      return 4*pi*rho0*rs*rs*rs*(std::log((r+rs)/rs)-r/(r+rs));
    }

  private:
    std::string do_get_information()const
    {
      return "";
    }
  };
}



#endif
//EOF
