#ifndef DUMP_FIT_QDP_HPP
#define DUMP_FIT_QDP_HPP

#include <core/fitter.hpp>
#include <vector>
#include <iostream>
#include <string>

namespace opt_utilities
{
  void dump_sbp_beta(std::ostream& os,fitter<double,double,std::vector<double>,double,std::string>& f,double cm_per_pixel,const std::vector<double>& r,const std::vector<double>& y,const std::vector<double>& ye);
  void dump_rho_beta(std::ostream& os,fitter<std::vector<double>,std::vector<double>,std::vector<double>,double,std::string>& f,double cm_per_pixel,const std::vector<double>& r,const std::vector<double>& sbps,const std::vector<double>& sbpe);
  void dump_rho_dbeta(std::ostream& os,fitter<std::vector<double>,std::vector<double>,std::vector<double>,double,std::string>& f,double cm_per_pixel);
};

#endif
