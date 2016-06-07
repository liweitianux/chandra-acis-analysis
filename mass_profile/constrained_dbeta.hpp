#ifndef CONSTRAINED_DBETA
#define CONSTRAINED_DBETA
#include "projector.hpp"
#include <iostream>


namespace opt_utilities
{
    template <typename T>
    class constrained_dbeta
      :public model<std::vector<T>,std::vector<T>,std::vector<T> >
    {
    public:
      constrained_dbeta()
      {
        this->push_param_info(param_info<std::vector<T>,std::string>("n01",1));
        this->push_param_info(param_info<std::vector<T>,std::string>("beta1",.66));
        this->push_param_info(param_info<std::vector<T>,std::string>("rc1",100));

        this->push_param_info(param_info<std::vector<T>,std::string>("n02",1));
        this->push_param_info(param_info<std::vector<T>,std::string>("beta2",.67));
        this->push_param_info(param_info<std::vector<T>,std::string>("rc2",110));
      }

  public:
    constrained_dbeta<T>* do_clone()const
    {
      return new constrained_dbeta<T>(*this);
    }

    std::vector<T> do_eval(const std::vector<T> & x, const std::vector<T>& p)
    {
      T n01=std::abs(p[0]);
      T beta1=p[1];
      T rc1=p[2];

      T n02=std::abs(p[3]);
      T beta2=p[4];
      T rc2=p[5];

      std::vector<T> result(x.size()-1);
      for(int i=1;i<x.size();++i)
        {
          T xi=(x[i]+x[i-1])/2;
          T yi=0;
          yi=n01*pow(1+xi*xi/rc1/rc1,-3./2.*beta1)+n02*pow(1+xi*xi/rc2/rc2,-3./2.*beta2);
          result[i-1]=yi;
        }
      return result;
    }

    bool do_meets_constraint(const std::vector<T>& p)const
    {
      if(p.size()!=6)
        {
          std::cerr<<p.size()<<std::endl;
          std::cerr<<this->get_num_params()<<std::endl;
          assert(0);
        }

      T rc1=p.at(2);
      T rc2=p.at(5);
      if(rc2>rc1)
        {
          return true;
        }
      else
        {
          std::cerr<<rc2<<"\t"<<rc1<<std::endl;
          std::cerr<<"***"<<std::endl;
          return false;
        }
    }
  };
}

#endif
