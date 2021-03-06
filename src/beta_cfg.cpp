#include "beta_cfg.hpp"
#include <sstream>
#include <cstdlib>
using namespace std;

cfg_map parse_cfg_file(std::istream& is)
{
  cfg_map result;
  result.rmin_pixel=-1;
  result.rmin_kpc=-1;
  for(;;)
    {
      std::string line;
      getline(is,line);
      line+="\n";
      if(!is.good())
	{
	  break;
	}
      string key;
      istringstream iss(line);
      iss>>key;
      if(key=="sbp_data")
	{
	  string value;
	  iss>>value;
	  result.sbp_data=value;
	}
      else if(key=="cfunc_profile")
	{
	  string value;
	  iss>>value;
	  result.cfunc_profile=value;
	}
      else if(key=="tprofile")
	{
	  string value;
	  iss>>value;
	  result.tprofile=value;
	}
      else if(key=="z")
	{
	  double z;
	  iss>>z;
	  result.z=z;
	}
      else if(key=="cm_per_pixel")
	{
	  double cm_per_pixel;
	  iss>>cm_per_pixel;
	  result.cm_per_pixel=cm_per_pixel;
	}
      else if(key=="rmin_pixel")
	{
	  double v;
	  iss>>v;
	  result.rmin_pixel=v;
	}
      else if(key=="rmin_kpc")
	{
	  double v;
	  iss>>v;
	  result.rmin_kpc=v;
	}
      else
	{
	  std::vector<double> value;
	  for(;;)
	    {
	      double v;
	      iss>>v;
	      if(!iss.good())
		{
		  break;
		}
	      value.push_back(v);
	    }
	  if(!value.empty())
	    {
	      result.param_map[key]=value;
	    }
	}
    }
  return result;
}
