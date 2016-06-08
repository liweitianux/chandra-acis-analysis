/**
   \file chisq.hpp
   \brief chi-square statistic
   \author Junhua Gu
 */

#ifndef CHI_SQ_HPP
#define CHI_SQ_HPP
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
  static const int display_interval=10;
  /**
     \brief chi-square statistic
     \tparam Ty the return type of model
     \tparam Tx the type of the self-var
     \tparam Tp the type of model parameter
     \tparam Ts the type of the statistic
     \tparam Tstr the type of the string used
   */
  template<typename Ty,typename Tx,typename Tp,typename Ts,typename Tstr>
  class chisq
    :public statistic<Ty,Tx,Tp,Ts,Tstr>
  {
  };
  template<>
  class chisq<double,double,std::vector<double>,double,std::string>
    :public statistic<double,double,std::vector<double> ,double,std::string>
  {
  public:
    typedef double Ty;
    typedef double Tx;
    typedef std::vector<double> Tp;
    typedef double Ts;
    typedef std::string Tstr;
  private:
    bool verb;
    bool limit_bound;
    int n;

    statistic<Ty,Tx,Tp,Ts,Tstr>* do_clone()const
    {
      // return const_cast<statistic<Ty,Tx,Tp>*>(this);
      return new chisq<Ty,Tx,Tp,Ts,Tstr>(*this);
    }

    const char* do_get_type_name()const
    {
      return "chi^2 statistics (specialized for double)";
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
    chisq()
      :verb(true),limit_bound(false)
    {}



    Ty do_eval(const Tp& p)
    {
      if(limit_bound)
	{
	  Tp p1=this->get_fitter().get_model().reform_param(p);
	  for(size_t i=0;i<p1.size();++i)
	    {
	      if(p1[i]>this->get_fitter().get_param_info(i).get_upper_limit()||
		 p1[i]<this->get_fitter().get_param_info(i).get_lower_limit())
		{
		  return 1e99;
		}
	    }
	}
      Ty result(0);
      std::vector<float> vx;
      std::vector<float> vy;
      std::vector<float> vye1;
      std::vector<float> vye2;
      std::vector<float> my;
      float xmin=1e99,xmax=-1e99,ymin=1e99,ymax=-1e99;
      if(verb)
	{
	  n++;
	  if(n%display_interval==0)
	    {
	      vx.resize(this->get_data_set().size());
	      vy.resize(this->get_data_set().size());
	      vye1.resize(this->get_data_set().size());
	      vye2.resize(this->get_data_set().size());
	      my.resize(this->get_data_set().size());
	    }

	}

      for(int i=(this->get_data_set()).size()-1;i>=0;--i)
	{

#ifdef HAVE_X_ERROR
	  Tx x1=this->get_data_set().get_data(i).get_x()-this->get_data_set().get_data(i).get_x_lower_err();
	  Tx x2=this->get_data_set().get_data(i).get_x()+this->get_data_set().get_data(i).get_x_upper_err();
	  Tx x=this->get_data_set().get_data(i).get_x();
	  Ty errx1=(this->eval_model(x1,p)-this->eval_model(x,p));
	  Ty errx2=(this->eval_model(x2,p)-this->eval_model(x,p));
	  //Ty errx=0;
#else
	  Ty errx1=0;
	  Ty errx2=0;
#endif

	  Ty y_model=this->eval_model(this->get_data_set().get_data(i).get_x(),p);
	  Ty y_obs=this->get_data_set().get_data(i).get_y();
	  Ty y_err;

	  Ty errx=0;
	  if(errx1<errx2)
	    {
	      if(y_obs<y_model)
		{
		  errx=errx1>0?errx1:-errx1;
		}
	      else
		{
		  errx=errx2>0?errx2:-errx2;
		}
	    }
	  else
	    {
	      if(y_obs<y_model)
		{
		  errx=errx2>0?errx2:-errx2;
		}
	      else
		{
		  errx=errx1>0?errx1:-errx1;
		}
	    }


	  if(y_model>y_obs)
	    {
	      y_err=this->get_data_set().get_data(i).get_y_upper_err();
	    }
	  else
	    {
	      y_err=this->get_data_set().get_data(i).get_y_lower_err();
	    }

	  Ty chi=(y_obs-y_model)/std::sqrt(y_err*y_err+errx*errx);

	  result+=chi*chi;

	  if(verb&&n%display_interval==0)
	    {
	      vx.at(i)=this->get_data_set().get_data(i).get_x();
	      vy.at(i)=this->get_data_set().get_data(i).get_y();
	      vye1.at(i)=std::abs(this->get_data_set().get_data(i).get_y_lower_err());
	      vye2.at(i)=std::abs(this->get_data_set().get_data(i).get_y_upper_err());
	      my.at(i)=y_model;

	      xmin=std::min(vx.at(i),xmin);
	      ymin=std::min(vy.at(i),ymin-vye1[i]);
	      xmax=std::max(vx.at(i),xmax);
	      ymax=std::max(vy.at(i),ymax+vye2[i]);
	    }


	}
      if(verb)
	{
	  if(n%display_interval==0)
	    {
	      cerr<<result<<"\t";
	      for(size_t i=0;i<get_size(p);++i)
		{
		  cerr<<get_element(p,i)<<",";
		}
	      cerr<<endl;
	      //cerr<<x1<<"\t"<<x2<<endl;
	      pr.init_xyrange(xmin,xmax,ymin,ymax,0);
	      pr.plot_err2_dot(vx,vy,vye1,vye2);
	      pr.plot_line(vx,my);
	      cpgask(0);
	    }

	}

      return result;
    }
  };


}

#endif
//EOF
