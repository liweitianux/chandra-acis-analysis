/*
  Perform a double-beta density model fitting to the surface brightness data
  Author: Junhua Gu
  Last modified: 2011.01.01
  This code is distributed with no warrant
*/

//#define HAVE_X_ERROR
#include <iomanip>
#include <iostream>
#include <sstream>
#include <fstream>
#include <models/pl1d.hpp>
#include <models/lin1d.hpp>
#include "statistics/chisq.hpp"
#include "statistics/leastsq.hpp"
#include "statistics/robust_chisq.hpp"
#include <data_sets/default_data_set.hpp>
#include <methods/powell/powell_method.hpp>
#include <core/freeze_param.hpp>

using namespace std;
using namespace opt_utilities;
//double s=5.63136645E20;
const double kpc=3.086E21;//kpc in cm
const double Mpc=kpc*1000;
const double pi=4*atan(1);
double std_norm_rand()
{
  double u=0;
  double v=0;
  while(u<=0||v<=0)
    {
      u=rand()/(double)RAND_MAX;
      rand();
      v=rand()/(double)RAND_MAX;
    }
  double x=std::sqrt(-log(u))*cos(2*pi*v);
  return x;
}

double shuffle_data(double xc,double xl,double xu)
{
  if(std_norm_rand()>0)
    {
      double result=xc-std::abs(std_norm_rand()*xl);
      return result;
    }
  else
    {
      double result= xc+std::abs(std_norm_rand()*xu);
      return result;
    }
}

int main(int argc,char* argv[])
{
  if(argc!=3)
    {
      cerr<<"Usage:"<<argv[0]<<" <a 6 column file with T -Terr +Terr M -Merr +Merr> <lower T limit>"<<endl;
      return -1;
    }
  double T_lower_limit(atof(argv[2]));
  ifstream ifs_data(argv[1]);
  default_data_set<double,double> ds;
  ofstream ofs_result("m-t_result.qdp");
  ofs_result<<"read terr 1 2"<<endl;
  ofs_result<<"skip single"<<endl;
  ofs_result<<"log"<<endl;
  //ofs_result<<"li on 2"<<endl;
  ofs_result<<"time off"<<endl;
  ofs_result<<"la f"<<endl;
  ofs_result<<"la x temperature (keV)"<<endl;
  ofs_result<<"la y mass (M\\dsun\\u)"<<endl;
  double sxx=0;
  double s1=0;
  double sx=0;
  double sy=0;
  double sxy=0;
  bool is_first_nonono=true;

  for(;;)
    {
      double T,Tl,Tu;
      double M,Ml,Mu;
      std::string line;
      getline(ifs_data,line);
      //ifs_data>>T>>Tl>>Tu>>M>>Ml>>Mu;
      if(!ifs_data.good())
	{
	  break;
	}
      line+=" ";
      istringstream iss(line);

      if(line[0]=='#')
	{
	  if(!is_first_nonono)
	    {
	      ofs_result<<"no no no"<<endl;
	    }
	  else
	    {
	      is_first_nonono=false;
	    }
	  continue;
	}
      iss>>T>>Tl>>Tu>>M>>Ml>>Mu;
      //std::cerr<<L<<"\t"<<Lerr<<endl;
      if(!iss.good())
	{
	  continue;
	}

      if(T<T_lower_limit||M<0)
	{
	  continue;
	}
      if(std::abs(Mu)<M*.1||std::abs(Ml)<M*.1)
	{
	  cerr<<"mass error less than 10%, skipped"<<endl;
	  cerr<<line<<endl;
	  continue;
	}
#if 1
      if(std::abs(Tu)<.1||std::abs(Tl)<.1)
	{
	  cerr<<"T error less than 10%, skipped"<<endl;
	  cerr<<line<<endl;
	  continue;
	}
#endif
      if(std::abs(Mu)+std::abs(Ml)<M*.1)
	{
	  double k=M*.1/(std::abs(Mu)+std::abs(Ml));
	  Mu*=k;
	  Ml*=k;
	}
      Tl=std::abs(Tl);
      Tu=std::abs(Tu);
      Ml=std::abs(Ml);
      Mu=std::abs(Mu);
      ofs_result<<T<<"\t"<<-std::abs(Tl)<<"\t"<<+std::abs(Tu)<<"\t"<<M<<"\t"<<-std::abs(Ml)<<"\t"<<+std::abs(Mu)<<endl;
      double x=log(T);
      double y=log(M);
      double xu=log(T+Tu)-log(T);
      double xl=log(T-Tl)-log(T);

      double yu=log(M+Mu)-log(M);
      double yl=log(M-Ml)-log(M);
      if(isnan(x)||isnan(y)||isnan(yl)||isnan(yu)||
	 isnan(xl)||isnan(xu))
	{
	  std::cerr<<"one data with error > data, skipped"<<endl;
	  std::cerr<<line<<endl;
	  continue;
	}
      sxx+=x*x;
      sx+=x;
      sy+=y;
      sxy+=y*x;
      s1+=1;
      data<double,double> d(x,y,std::abs(yl),std::abs(yu),
			    std::abs(xl),std::abs(xu));
      ds.add_data(d);
    }

  double M=sxx*s1-sx*sx;
  double Ma=sxy*s1-sy*sx;
  double Mb=sxx*sy-sx*sxy;
  double k0=Ma/M;
  double b0=Mb/M;

  ofs_result<<"no no no"<<endl;
  fitter<double,double,vector<double>,double,std::string> fit;
  fit.set_opt_method(powell_method<double,vector<double> >());
  fit.set_statistic(chisq<double,double,vector<double>,double,std::string>());
  //fit.set_statistic(robust_chisq<double,double,vector<double>,double,std::string>());
  //fit.set_statistic(leastsq<double,double,vector<double>,double,std::string>());
  fit.set_model(lin1d<double>());
  fit.load_data(ds);

  cerr<<"k0="<<k0<<endl;
  cerr<<"b0="<<b0<<endl;
  cerr<<"Ampl0="<<exp(b0)<<endl;
  cerr<<"gamma0="<<k0<<endl;
  fit.set_param_value("k",k0);
  fit.set_param_value("b",b0);
  std::vector<double> p=fit.get_all_params();
  std::cout<<"chi="<<fit.get_statistic().eval(p)<<std::endl;
  fit.fit();
  fit.fit();
  p=fit.fit();

  std::cout<<"chi="<<fit.get_statistic().eval(p)<<std::endl;
  for(double i=.5;i<12;i*=1.01)
    {
      ofs_result<<i<<"\t0\t0\t"<<exp(fit.eval_model_raw(log(i),p))<<"\t0\t0\n";
    }

  ofstream ofs_resid("resid.qdp");
  ofs_resid<<"read terr 1 2 3"<<endl;
  ofs_resid<<"skip single"<<endl;
  ofs_resid<<"ma 3 on 1"<<endl;
  ofs_resid<<"log x"<<endl;
  for(size_t i=0;i<ds.size();++i)
    {
      double x=ds.get_data(i).get_x();
      double y=ds.get_data(i).get_y();
      //double xe1=-ds.get_data(i).get_x_lower_err()*0;
      //double xe2=ds.get_data(i).get_x_upper_err()*0;
      double ye1=-ds.get_data(i).get_y_lower_err();
      double ye2=ds.get_data(i).get_y_upper_err();
      ofs_resid<<exp(x)<<"\t"<<0<<"\t"<<0<<"\t"<<y-fit.eval_model_raw(x,p)<<"\t"<<ye1<<"\t"<<ye2<<"\t"<<"0\t0\t0"<<endl;
    }
  double mean_A=0;
  double mean_A2=0;
  double mean_g=0;
  double mean_g2=0;
  int cnt=0;
  for(int n=0;n<100;++n)
    {
      ++cnt;
      cerr<<".";
      opt_utilities::default_data_set<double,double> ds1;
      for(size_t i=0;i<ds.size();++i)
	{
	  double new_x=shuffle_data(ds.get_data(i).get_x(),
				    ds.get_data(i).get_x_lower_err(),
				    ds.get_data(i).get_x_upper_err());
	  double new_y=shuffle_data(ds.get_data(i).get_y(),
				    ds.get_data(i).get_y_lower_err(),
				    ds.get_data(i).get_y_upper_err());
	  ds1.add_data(data<double,double>(new_x,new_y,
					   ds.get_data(i).get_y_lower_err(),
					   ds.get_data(i).get_y_upper_err(),
					   ds.get_data(i).get_y_lower_err(),
					   ds.get_data(i).get_y_upper_err()));
	}
      fit.load_data(ds1);

      fit.fit();
      double k=fit.get_param_value("k");
      double b=fit.get_param_value("b");
      double A=exp(b);
      double g=k;
      mean_A+=A;
      mean_A2+=A*A;
      mean_g+=g;
      mean_g2+=g*g;
    }
  std::cerr<<endl;
  mean_A/=cnt;
  mean_A2/=cnt;
  mean_g/=cnt;
  mean_g2/=cnt;
  double std_A=std::sqrt(mean_A2-mean_A*mean_A);
  double std_g=std::sqrt(mean_g2-mean_g*mean_g);

  std::cerr<<"M=M0*T^gamma"<<endl;
  std::cout<<"M0= "<<exp(p[1])<<"+/-"<<std_A<<endl;
  std::cout<<"gamma= "<<p[0]<<"+/-"<<std_g<<endl;
  std::cout<<"Num of sources:"<<ds.size()<<endl;

}
