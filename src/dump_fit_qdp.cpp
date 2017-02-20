#include "dump_fit_qdp.hpp"

namespace opt_utilities
{
  const static double kpc=3.086E21;
  void dump_sbp_beta(std::ostream& os,fitter<double,double,std::vector<double>,double,std::string>& f,double cm_per_pixel,const std::vector<double>& r,const std::vector<double>& y,const std::vector<double>& ye)
  {
    os<<"read serr 1 2"<<std::endl;
    os<<"skip single"<<std::endl;
    os<<"la x \"radius (kpc)\""<<std::endl;
    os<<"la y \"surface brightness (cts s\\u-1\\d pixel\\u-2\\d)\""<<std::endl;
    os<<"li on 2"<<std::endl;
    for(size_t i=1;i<r.size();++i)
      {
	os<<(r[i]+r[i-1])/2*cm_per_pixel/kpc<<"\t"<<(r[i]-r[i-1])/2*cm_per_pixel/kpc<<"\t"<<y[i-1]<<"\t"<<ye[i-1]<<std::endl;
      }
    os<<"no no no"<<std::endl;
    std::vector<double> p=f.get_all_params();
    for(size_t i=1;i<r.size();++i)
      {
	double x=(r[i]+r[i-1])/2;
	os<<x*cm_per_pixel/kpc<<"\t"<<0<<"\t"<<f.eval_model_raw(x,p)<<"\t"<<0<<std::endl;
      }
  }

  void dump_rho_beta(std::ostream& os,fitter<std::vector<double>,std::vector<double>,std::vector<double>,double,std::string>& f,double cm_per_pixel,const std::vector<double>& r,const std::vector<double>& sbps,const std::vector<double>& sbpe)
  {
    os<<"read serr 1 2"<<std::endl;
    os<<"skip single"<<std::endl;
    os<<"la x \"radius (kpc)\""<<std::endl;
    os<<"la y \"density (cm\\u-3\\d)\""<<std::endl;
    os<<"li on 2"<<std::endl;

    for(size_t i=1;i<r.size();++i)
    {
      double x=(r[i]+r[i-1])/2;
      double y=sbps[i-1];
      double ye=sbpe[i-1];
      os<<x*cm_per_pixel/kpc<<"\t0\t"<<y<<"\t"<<ye<<std::endl;
    }

    os<<"no no no"<<std::endl;
    std::vector<double> p=f.get_all_params();
    std::vector<double> mv=f.eval_model_raw(r,p);
    for(size_t i=1;i<r.size();++i)
    {
      double x=(r[i]+r[i-1])/2;
      double y=mv[i-1];
      double ye=0;
      os<<x*cm_per_pixel/kpc<<"\t0\t"<<y<<"\t"<<ye<<std::endl;
    }

  }

};
