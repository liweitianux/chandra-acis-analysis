#ifndef BETA_CFG
#define BETA_CFG

#include <map>
#include <vector>
#include <string>
#include <iostream>

struct cfg_map
{
  std::string sbp_data;
  std::string cfunc_profile;
  std::string tprofile;
  double z;
  double cm_per_pixel;
  double rmin_kpc;
  double rmin_pixel;
  std::map<std::string,std::vector<double> > param_map;
};

cfg_map parse_cfg_file(std::istream& is);

#endif
