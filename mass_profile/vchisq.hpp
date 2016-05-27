/**
   \file vchisq.hpp
   \brief chi-square statistic
   \author Junhua Gu
 */

#ifndef VCHI_SQ_HPP
#define VCHI_SQ_HPP
#define OPT_HEADER
#include <core/fitter.hpp>
#include <iostream>
#include <vector>
#include <misc/optvec.hpp>
#include <cmath>
#include "plot_reporter.hpp"
#include <cpgplot.h>
using std::cerr;using std::endl;

namespace opt_utilities
{

  template<typename T>
  class vchisq
    :public statistic<std::vector<T>,std::vector<T>,std::vector<T>,T,std::string>
  {
  private:
    bool verb;
    int n;
    bool limit_bound;
    typedef std::vector<T> Tp;
    
    vchisq<T>* do_clone()const
    {
      return new vchisq<T>(*this);
    }

    const char* do_get_type_name()const
    {
      return "chi^2 statistic";
    }
    
  public:
    void verbose(bool v)
    {
      verb=v;
    }

    void set_limit()
    {
      limit_bound=true;
    }
    
    void clear_limit()
    {
      limit_bound=false;
    }
  public:
    vchisq()
      :verb(false),limit_bound(false)
    {}
    
    

    T do_eval(const std::vector<T>& p)
    {
      if(limit_bound)
	{
	  if(!this->get_fitter().get_model().meets_constraint(p))
	    {
	      return 1e99;
	    }
	}
      T result(0);
      
      std::vector<float> vx;
      std::vector<float> vy;
      std::vector<float> vye;
      std::vector<float> my;
      float x1=1e99,x2=-1e99,y1=1e99,y2=-1e99;
      if(verb)
	{
	  n++;
	  
	  if(n%100==0)
	    {
	      vx.resize(this->get_data_set().get_data(0).get_y().size());
	      vy.resize(this->get_data_set().get_data(0).get_y().size());
	      vye.resize(this->get_data_set().get_data(0).get_y().size());
	      my.resize(this->get_data_set().get_data(0).get_y().size());
	    }
	  
	}
      for(int i=(this->get_data_set()).size()-1;i>=0;--i)
	{
	  const std::vector<double> y_model(this->eval_model(this->get_data_set().get_data(i).get_x(),p));
	  const std::vector<double>& y=this->get_data_set().get_data(i).get_y();
	  const std::vector<double>& ye=this->get_data_set().get_data(i).get_y_lower_err();
	  for(int j=0;j<y.size();++j)
	    {
	      double chi=(y_model[j]-y[j])/ye[j];
	      result+=chi*chi;
	    }
	  
	  
	  if(verb&&n%100==0)
	    {
	      
	      for(int j=0;j<y.size();++j)
		{
		  vx.at(j)=((this->get_data_set().get_data(i).get_x().at(j)+this->get_data_set().get_data(i).get_x().at(j+1))/2.);
		  vy.at(j)=(y[j]);
		  vye.at(j)=ye[j];
		  my.at(j)=(y_model[j]);
		  x1=std::min(vx.at(j),x1);
		  y1=std::min(vy.at(j),y1);
		  x2=std::max(vx.at(j),x2);
		  y2=std::max(vy.at(j),y2);
		  vye[j]=log10(vy[j]+vye[j])-log10(vy[j]);
		  vx[j]=log10(vx[j]);
		  vy[j]=log10(vy[j]);
		  my[j]=log10(my[j]);

		}
		
	    }
	      
	}
      if(verb)
	{

	  if(n%100==0)
	    {

	      cerr<<result<<"\t";
	      for(size_t i=0;i<get_size(p);++i)
		{
		  cerr<<get_element(p,i)<<",";
		}
	      cerr<<endl;
	    }
	  if(n%100==0)
	    {
	      //cpgask(1);
	      //std::cerr<<x1<<"\t"<<y1<<std::endl;
	      pr.init_xyrange(log10(x1/1.5),log10(x2*1.5),log10(y1/1.5),log10(y2*1.5),30);
	      //pr.init_xyrange((x1),(x2),(y1),(y2));
	      pr.plot_err1_dot(vx,vy,vye);
	      pr.plot_line(vx,my);
	    }
	}
      
      return result;
    }
  };

}
#endif
