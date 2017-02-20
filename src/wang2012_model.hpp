/**
   \file wang2012_model.hpp
   \brief Jingying Wang's model
   \author Jingying Wang
 */


#ifndef WANG2012_MODEL
#define WANG2012_MODEL
#define OPT_HEADER
#include <core/fitter.hpp>
#include <cmath>

namespace opt_utilities
{
  template <typename T>
  class wang2012_model
    :public model<T,T,std::vector<T>,std::string>
  {
  private:
    model<T,T,std::vector<T> >* do_clone()const
    {
      return new wang2012_model<T>(*this);
    }

    const char* do_get_type_name()const
    {
      return "1d power law";
    }
  public:
    wang2012_model()
    {
      this->push_param_info(param_info<std::vector<T> >("A",5,0,500));
      this->push_param_info(param_info<std::vector<T> >("n",1.66,0,10));
      this->push_param_info(param_info<std::vector<T> >("xi",0.45,0,1));
      this->push_param_info(param_info<std::vector<T> >("a2",1500,0,1e8));
      this->push_param_info(param_info<std::vector<T> >("a3",50,0,1e8));
      this->push_param_info(param_info<std::vector<T> >("beta",0.49,0.1,0.7));
      this->push_param_info(param_info<std::vector<T> >("T0",0,0,10));
      
    }

    T do_eval(const T& x,const std::vector<T>& param)
    {
      T A=param[0];
      T n=param[1];
      T xi=param[2];
      T a2=param[3];
      T a3=param[4];
      T beta=param[5];
      T T0=param[6];
        return A*(pow(x,n)+xi*a2)/(pow(x,n)+a2)/pow(1+x*x/a3/a3,beta)+T0;
      //return A*(pow(x,n)+a1)/(pow(x,n)+1)/pow(1+x*x/a3/a3,beta)+T0;
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
