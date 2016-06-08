#include <iostream>
#include <string>
#include <vector>
#include <statistics/chisq.hpp>
#include <methods/powell/powell_method.hpp>
#include <data_sets/default_data_set.hpp>
#include <misc/data_loaders.hpp>
#include "methods/aga/aga.hpp"
#include <models/beta1d.hpp>
using namespace std;
using namespace opt_utilities;



int main(int argc,char* argv[])
{

  if(argc!=2)
    {
      cerr<<"Usage:"<<argv[0]<<" <sbp data>"<<endl;
      return -1;
    }

  fitter<double,double,vector<double>,double,string> f;

  f.set_statistic(chisq<double,double,vector<double>,double,string>());
  f.set_opt_method(powell_method<double,vector<double> >());
  f.set_model(beta1d<double>());
  dl_x_xe_y_ye<double,double> dl;
  ifstream ifs(argv[1]);
  ifs>>dl;
  f.load_data(dl.get_data_set());
  f.fit();

  double rmin=f.get_data_set().get_data(0).get_x();
  double rmax=f.get_data_set().get_data(f.get_data_set().size()-1).get_x();
  cout<<"read terr 1 2\nskip single\n";
  for(size_t i=0;i<f.get_data_set().size();++i)
    {
      cout<<f.get_data_set().get_data(i).get_x()<<"\t"<<
	-abs(f.get_data_set().get_data(i).get_x_lower_err())<<"\t"<<
	abs(f.get_data_set().get_data(i).get_x_upper_err())<<"\t"<<
	f.get_data_set().get_data(i).get_y()<<"\t"<<
	-abs(f.get_data_set().get_data(i).get_y_lower_err())<<"\t"<<
	abs(f.get_data_set().get_data(i).get_y_upper_err())<<endl;


    }
  cout<<"no no no\n";

  for(double i=rmin;i<rmax;i+=1)
    {
      cout<<i<<"\t0\t0\t"<<f.eval_model(i,f.get_all_params())<<"\t0\t0"<<endl;
    }

  for(size_t i=0;i<f.get_num_params();++i)
    {
      cerr<<f.get_param_info(i).get_name()<<"="<<
	f.get_param_info(i).get_value()<<endl;
    }
}
