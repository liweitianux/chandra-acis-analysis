#ifndef PROJ_HPP
#define PROJ_HPP
/*
  Defining the class that is used to consider the projection effect
  Author: Junhua Gu
  Last modified: 2011.01.01
*/


#include <core/fitter.hpp>
#include <vector>
#include <cmath>

static const double pi=4*atan(1);
// Ratio of the electron density (n_e) to the proton density (n_p)
//   n_gas = n_e + n_p ~= 1.826 n_e  =>  n_e / n_p ~= 1.21
// Reference: Ettori et al. 2013, Space Sci. Rev., 177, 119-154; Eq.(9) below
static const double ne_np_ratio = 1.21;

namespace opt_utilities
{
  //This is used to project a 3-D surface brightness model to 2-D profile
  template <typename T>
  class projector
    :public model<std::vector<T>,std::vector<T>,std::vector<T> >
  {
  private:
    //Points to a 3-D model that is to be projected
    model<std::vector<T>,std::vector<T>,std::vector<T> >* pmodel;
    func_obj<T,T>* pcfunc;
    T cm_per_pixel;
  public:
    //default cstr
    projector()
      :pmodel(NULL_PTR),pcfunc(NULL_PTR),cm_per_pixel(1)
    {}
    //copy cstr
    projector(const projector& rhs)
      :cm_per_pixel(rhs.cm_per_pixel)
    {
      attach_model(*(rhs.pmodel));
      if(rhs.pcfunc)
        {
          pcfunc=rhs.pcfunc->clone();
        }
      else
        {
          pcfunc=NULL_PTR;
        }
    }
    //assign operator
    projector& operator=(const projector& rhs)
    {
      cm_per_pixel=rhs.cm_per_pixel;
      if(pmodel)
        {
          pmodel->destroy();
        }
      if(pcfunc)
        {
          pcfunc->destroy();
        }
      if(rhs.pcfunc)
        {
          pcfunc=rhs.pcfunc->clone();
        }
      if(rhs.pmodel)
        {
          pmodel=rhs.pmodel->clone();
        }
    }
    //destr
    ~projector()
    {
      if(pmodel)
        {
          pmodel->destroy();
        }
      if(pcfunc)
        {
          pcfunc->destroy();
        }
    }
    //used to clone self
    model<std::vector<T>,std::vector<T>,std::vector<T> >*
    do_clone()const
    {
      return new projector(*this);
    }

  public:
    void set_cm_per_pixel(const T& x)
    {
      cm_per_pixel=x;
    }

    //attach the model that is to be projected
    void attach_model(const model<std::vector<T>,std::vector<T>,std::vector<T> >& m)
    {
      this->clear_param_info();
      for(size_t i=0;i<m.get_num_params();++i)
        {
          this->push_param_info(m.get_param_info(i));
        }
      this -> push_param_info(param_info<std::vector<T>,
                              std::string>("bkg",0,0,1E99));
      pmodel=m.clone();
      pmodel->clear_param_modifier();
    }

    void attach_cfunc(const func_obj<T,T>& cf)
    {
      if(pcfunc)
        {
          pcfunc->destroy();
        }
      pcfunc=cf.clone();
    }

  public:
    //calc the volume
    /*
      This is a sphere that is subtracted by a cycline.
       /|     |\
      / |     | \
      | |     | |
      | |     | |
      \ |     | /
       \|     |/
     */
    T calc_v_ring(T rsph,T rcyc)
    {
      if(rcyc<rsph)
        {
          double a=rsph*rsph-rcyc*rcyc;
          return 4.*pi/3.*std::sqrt(a*a*a);
        }
      return 0;
    }

    //calc the No. nsph sphere's projection volume on the No. nrad pie region
    T calc_v(const std::vector<T>& rlist,int nsph,int nrad)
    {
      if(nsph<nrad)
        {
          return 0;
        }
      else if(nsph==nrad)
        {
          return calc_v_ring(rlist[nsph+1], rlist[nrad]);
        }
      else {
        return (calc_v_ring(rlist[nsph+1], rlist[nrad]) -
                calc_v_ring(rlist[nsph], rlist[nrad]) -
                calc_v_ring(rlist[nsph+1], rlist[nrad+1]) +
                calc_v_ring(rlist[nsph], rlist[nrad+1]));
      }
    }
  public:
    bool do_meets_constraint(const std::vector<T>& p)const
    {
      std::vector<T> p1(this->reform_param(p));
      for(size_t i=0;i!=p1.size();++i)
        {
          if(get_element(p1,i)>this->get_param_info(i).get_upper_limit()||
            get_element(p1,i)<this->get_param_info(i).get_lower_limit())
            {
              // std::cerr<<this->get_param_info(i).get_name()<<"\t"<<p1[i]<<std::endl;
              return false;
            }
        }
      std::vector<T> p2(p1.size()-1);
      for(size_t i=0;i<p1.size()-1;++i)
        {
          p2.at(i)=p1[i];
        }

      return pmodel->meets_constraint(p2);
    }
  public:
    //Perform the projection
    std::vector<T> do_eval(const std::vector<T>& x,const std::vector<T>& p)
    {
      T bkg=std::abs(p.back());
      //I think following codes are clear enough :).
      std::vector<T> unprojected(pmodel->eval(x,p));
      std::vector<T> projected(unprojected.size());

      for(size_t nrad=0; nrad<x.size()-1; ++nrad)
        {
          for(size_t nsph=nrad; nsph<x.size()-1; ++nsph)
            {
              double v = calc_v(x, nsph, nrad) * pow(cm_per_pixel, 3);
              if(pcfunc)
                {
                  double cfunc = (*pcfunc)((x[nsph+1] + x[nsph]) / 2.0);
                  projected[nrad] += (unprojected[nsph] * unprojected[nsph] *
                                      cfunc * v / ne_np_ratio);
                }
              else
                {
                  projected[nrad] += unprojected[nsph] * unprojected[nsph] * v;
                }
            }
          double area = pi * (x[nrad+1]*x[nrad+1] - x[nrad]*x[nrad]);
          projected[nrad] /= area;
          projected[nrad] += bkg;
        }
      return projected;
    }
  };
};

#endif
