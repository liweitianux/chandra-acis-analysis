#ifndef DBETA
#define DBETA
#include "projector.hpp"

/**
   dbeta: double beta model for density
   dbeta2: double beta model for density with only one beta
*/


namespace opt_utilities
{
  template <typename T>
  class dbeta
    :public model<std::vector<T>,std::vector<T>,std::vector<T> >
  {
  public:
    dbeta()
    {
      this->push_param_info(param_info<std::vector<T>,std::string>("n01",1));
      this->push_param_info(param_info<std::vector<T>,std::string>("beta1",.66));
      this->push_param_info(param_info<std::vector<T>,std::string>("rc1",100));

      this->push_param_info(param_info<std::vector<T>,std::string>("n02",1));
      this->push_param_info(param_info<std::vector<T>,std::string>("beta2",.67));
      this->push_param_info(param_info<std::vector<T>,std::string>("rc2",110));
      
    }

  public:
    dbeta<T>* do_clone()const
    {
      return new dbeta<T>(*this);
    }

    std::vector<T> do_eval(const std::vector<T> & x,
			   const std::vector<T>& p)
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
  };

  template <typename T>
  class dbeta2
    :public model<std::vector<T>,std::vector<T>,std::vector<T> >
  {
  public:
    dbeta2()
    {
      this->push_param_info(param_info<std::vector<T>,std::string>("n01",1));
      this->push_param_info(param_info<std::vector<T>,std::string>("rc1",100));
      this->push_param_info(param_info<std::vector<T>,std::string>("n02",1));
      this->push_param_info(param_info<std::vector<T>,std::string>("rc2",110));
      this->push_param_info(param_info<std::vector<T>,std::string>("beta",.67));
      
    }

  public:
    dbeta2<T>* do_clone()const
    {
      return new dbeta2<T>(*this);
    }

    std::vector<T> do_eval(const std::vector<T> & x,
			   const std::vector<T>& p)
    {
      T n01=std::abs(p[0]);
      T rc1=p[1];

      T n02=std::abs(p[2]);
      T rc2=p[3];
      T beta=p[4];
      T beta1=beta;
      T beta2=beta;

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
  };

}

#endif
