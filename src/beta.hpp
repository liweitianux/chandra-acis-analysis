#ifndef BETA
#define BETA
#include "projector.hpp"

namespace opt_utilities
{
  template <typename T>
  class beta
    :public model<std::vector<T>,std::vector<T>,std::vector<T> >
  {
  public:
    beta()
    {
      this->push_param_info(param_info<std::vector<T>,std::string>("n0",1,0,1E99));
      this->push_param_info(param_info<std::vector<T>,std::string>("beta",.66,0,1E99));
      this->push_param_info(param_info<std::vector<T>,std::string>("rc",100,0,1E99));
    }

  public:
    beta<T>* do_clone()const
    {
      return new beta<T>(*this);
    }

    std::vector<T> do_eval(const std::vector<T> & x,
			   const std::vector<T>& p)
    {
      T n0=std::abs(p[0]);
      T beta=p[1];
      T rc=p[2];

      std::vector<T> result(x.size()-1);
      for(size_t i=1;i<x.size();++i)
	{
	  T xi=(x[i]+x[i-1])/2;
	  T yi=0;
	  yi=n0*pow(1+xi*xi/rc/rc,-3./2.*beta);
	  result[i-1]=yi;
	}
      return result;
    }
  };
}

#endif
