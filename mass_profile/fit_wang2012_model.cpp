/*
  Fitting Jy Wang's temperature profile model
  Author: Jingying Wang
  Last modification 20120819

*/

#include "wang2012_model.hpp"
#include <core/optimizer.hpp>
#include <core/fitter.hpp>
#include <data_sets/default_data_set.hpp>
#include "chisq.hpp"
#include <methods/powell/powell_method.hpp>
#include <core/freeze_param.hpp>
#include <iostream>
#include <fstream>
#include <vector>
#include <string>

using namespace opt_utilities;
using namespace std;
const double cm=1;
const double kpc=3.08568e+21*cm;

int main(int argc,char* argv[])
{
  if(argc<2)
    {
      cerr<<"Usage:"<<argv[0]<<" <data file with 4 columns of x, xe, y, ye> [param file] [cm per pixel]"<<endl;
      return -1;
    }
  double cm_per_pixel=-1;
  if(argc>=4)
    {
      cm_per_pixel=atof(argv[3]);
    }

  //define the fitter
  fitter<double,double,vector<double>,double,std::string> fit;
  //define the data set
  default_data_set<double,double> ds;
  //open the data file
  ifstream ifs(argv[1]);
  double min_r=1e9;
  //cout<<"read serr 2"<<endl;
  ofstream ofs_fit_result("fit_result.qdp");
  ofs_fit_result<<"read serr 1 2"<<endl;
  ofs_fit_result<<"skip single"<<endl;
  if(cm_per_pixel>0)
    {
      ofs_fit_result<<"la x radius (kpc)"<<endl;
    }
  else
    {
      ofs_fit_result<<"la x radius (pixel)"<<endl;
    }
  ofs_fit_result<<"la y temperature (keV)"<<endl;
  for(;;)
    {
      //read radius, temperature and error
      double r,re,t,te;
      ifs>>r>>re>>t>>te;
      if(!ifs.good())
	{
	  break;
	}
      min_r=min(r,min_r);
      data<double,double> d(r,t,te,te,re,re);
      //std::cerr<<r<<"\t"<<t<<"\t"<<te<<endl;
      if(cm_per_pixel>0)
	{
	  ofs_fit_result<<r*cm_per_pixel/kpc<<"\t"<<re*cm_per_pixel/kpc<<"\t"<<t<<"\t"<<te<<endl;
	}
      else
	{
	  ofs_fit_result<<r<<"\t"<<re<<"\t"<<t<<"\t"<<te<<endl;
	}
      ds.add_data(d);
    }
  ofs_fit_result<<"no no no"<<endl;
  //load data
  fit.load_data(ds);
  //define the optimization method
  fit.set_opt_method(powell_method<double,vector<double> >());
  //use chi^2 statistic
  chisq<double,double,vector<double>,double,std::string> chisq_object;
  chisq_object.set_limit();
  fit.set_statistic(chisq_object);
  //fit.set_statistic(chisq<double,double,vector<double>,double,std::string>());
  fit.set_model(wang2012_model<double>());

  if(argc>=3&&std::string(argv[2])!="NONE")
    {
      std::vector<std::string> freeze_list;
      ifstream ifs_param(argv[2]);
      assert(ifs_param.is_open());
      for(;;)
	{
	  string pname;
	  double pvalue;
	  double lower,upper;
	  char param_status;
	  ifs_param>>pname>>pvalue>>lower>>upper>>param_status;
	  if(!ifs_param.good())
	    {
	      break;
	    }
	  if(param_status=='F')
	    {
	      freeze_list.push_back(pname);
	    }
	  if(pvalue<=lower||pvalue>=upper)
	    {
	      cerr<<"Invalid initial value, central value not enclosed by the lower and upper boundaries, adjust automatically"<<endl;
	      pvalue=std::max(pvalue,lower);
	      pvalue=std::min(pvalue,upper);
	    }
	  fit.set_param_value(pname,pvalue);
	  fit.set_param_lower_limit(pname,lower);
	  fit.set_param_upper_limit(pname,upper);
	}
      if(!freeze_list.empty())
	{
	  freeze_param<double,double,std::vector<double>,std::string> fp(freeze_list[0]);
	  fit.set_param_modifier(fp);
	  for(size_t i=1;i<freeze_list.size();++i)
	    {
	      dynamic_cast<freeze_param<double,double,std::vector<double>,std::string>&>(fit.get_param_modifier())+=freeze_param<double,double,std::vector<double>,std::string>(freeze_list[i]);
	    }
	}
    }

  for(int i=0;i<100;++i)
    {
      fit.fit();
    }
  vector<double> p=fit.fit();
#if 0
  ofstream output_param;
  if(argc>=3&&std::string(argv[2])!="NONE")
    {
      output_param.open(argv[2]);
    }
  else
    {
      output_param.open("para0.txt");
    }
#endif
  //output parameters
  for(size_t i=0;i<fit.get_num_params();++i)
    {
      std::string pname=fit.get_param_info(i).get_name();
      std::string pstatus=fit.get_model().report_param_status(pname);

      if(pstatus==""||pstatus=="thawed")
	{
	  pstatus="T";
	}
      else
	{
	  pstatus="F";
	}
      cout<<fit.get_param_info(i).get_name()<<"\t"<<fit.get_param_info(i).get_value()<<"\t"<<fit.get_param_info(i).get_lower_limit()<<"\t"<<fit.get_param_info(i).get_upper_limit()<<"\t"<<pstatus<<endl;
      //if(argc>=3&&std::string(argv[2])!="NONE")
#if 0
	{
	  output_param<<fit.get_param_info(i).get_name()<<"\t"<<fit.get_param_info(i).get_value()<<"\t"<<fit.get_param_info(i).get_lower_limit()<<"\t"<<fit.get_param_info(i).get_upper_limit()<<"\t"<<pstatus<<endl;
	}
#endif
    }

  //cout<<"T0"<<"\t"<<fit.get_param_value("T0")<<endl;
  //cout<<"T1"<<"\t"<<fit.get_param_value("T1")<<endl;
  //cout<<"xt"<<"\t"<<fit.get_param_value("xt")<<endl;
  //cout<<"eta"<<"\t"<<fit.get_param_value("eta")<<endl;
  //dump the data for checking
  ofstream ofs_model("wang2012_dump.qdp");


  min_r=0;
  for(double x=min_r;x<3000;x+=10)
    {
      double model_value=fit.eval_model_raw(x,p);

      ofs_model<<x<<"\t"<<model_value<<endl;
      if(cm_per_pixel>0)
	{
	  ofs_fit_result<<x*cm_per_pixel/kpc<<"\t0\t"<<model_value<<"\t0"<<endl;
	}
      else
	{
	  ofs_fit_result<<x<<"\t0\t"<<model_value<<"\t0"<<endl;
	}
    }
}
