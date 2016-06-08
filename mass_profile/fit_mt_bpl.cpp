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
#include <models/bpl1d.hpp>
#include <models/lin1d.hpp>
#include "statistics/chisq.hpp"
#include "statistics/logchisq.hpp"
#include "statistics/leastsq.hpp"
#include <data_sets/default_data_set.hpp>
#include <methods/powell/powell_method.hpp>
#include <methods/gsl_simplex/gsl_simplex.hpp>
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
  double lxc=log(xc);
  double lxl=log(xc-xl)-log(xc);
  double lxu=log(xc+xu)-log(xc);

  if(std_norm_rand()>0)
    {
      double result=std::exp(lxc-std::abs(std_norm_rand()*lxl));
      return result;
    }
  else
    {
      double result=std::exp(lxc+std::abs(std_norm_rand()*lxu));
      return result;
    }
}

int main(int argc,char* argv[])
{
  srand(time(0));
  if(argc!=4)
    {
      cerr<<"Usage:"<<argv[0]<<" <a 6 column file with T -Terr +Terr M -Merr +Merr> <initial broken temperature> <T lower limit>"<<endl;
      return -1;
    }
  double T_lower_limit(atof(argv[3]));
  double Tb=atof(argv[2]);
  assert(Tb>0);
  ifstream ifs_data(argv[1]);
  default_data_set<double,double> ds;
  ofstream ofs_result("m-t_bpl_result.qdp");
  ofs_result<<"read terr 1 2"<<endl;
  ofs_result<<"skip single"<<endl;
  ofs_result<<"log"<<endl;
  //ofs_result<<"li on 2"<<endl;
  ofs_result<<"time off"<<endl;
  ofs_result<<"la f"<<endl;
  ofs_result<<"la x temperature (keV)"<<endl;
  ofs_result<<"la y mass (M\\d\\(2281)\\u)"<<endl;
  double sxxl=0;
  double s1l=0;
  double sxl=0;
  double syl=0;
  double sxyl=0;

  double sxxu=0;
  double s1u=0;
  double sxu=0;
  double syu=0;
  double sxyu=0;

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
      if(std::abs(Ml)>std::abs(M))
	{
	  continue;
	}
      Tl=std::abs(Tl);
      Tu=std::abs(Tu);
      Ml=std::abs(Ml);
      Mu=std::abs(Mu);
      ofs_result<<T<<"\t"<<-std::abs(Tl)<<"\t"<<+std::abs(Tu)<<"\t"<<M<<"\t"<<-std::abs(Ml)<<"\t"<<+std::abs(Mu)<<endl;
      double x=(T);
      double y=(M);
      double xu=Tu;
      double xl=Tl;

      double yu=Mu;
      double yl=Ml;
      if(T>Tb)
	{
	  sxxl+=log(x)*log(x);
	  sxl+=log(x);
	  syl+=log(y);
	  sxyl+=log(y)*log(x);
	  s1l+=1;
	}
      else
	{
	  sxxu+=log(x)*log(x);
	  sxu+=log(x);
	  syu+=log(y);
	  sxyu+=log(y)*log(x);
	  s1u+=1;
	}
      data<double,double> d(x,y,std::abs(yl),std::abs(yu),
			    std::abs(xl),std::abs(xu));
      ds.add_data(d);
    }

  double Ml=sxxl*s1l-sxl*sxl;
  double Mal=sxyl*s1l-syl*sxl;
  double Mbl=sxxl*syl-sxl*sxyl;
  double k0l=Mal/Ml;
  double b0l=Mbl/Ml;

  double Mu=sxxu*s1u-sxu*sxu;
  double Mau=sxyu*s1u-syu*sxu;
  double Mbu=sxxu*syu-sxu*sxyu;
  double k0u=Mau/Mu;
  double b0u=Mbu/Mu;

  double gamma0l=k0l;
  double gamma0u=k0u;

  double ampl0l=exp(b0l)*pow(Tb,gamma0l);
  double ampl0u=exp(b0u)*pow(Tb,gamma0u);;



  ofs_result<<"no no no"<<endl;
  fitter<double,double,vector<double>,double,std::string> fit;
  fit.set_opt_method(powell_method<double,vector<double> >());

  fit.set_statistic(logchisq<double,double,vector<double>,double,std::string>());
  //fit.set_statistic(leastsq<double,double,vector<double>,double,std::string>());
  fit.set_model(bpl1d<double>());
  fit.load_data(ds);

  cerr<<"k0l="<<k0l<<endl;
  cerr<<"k0u="<<k0u<<endl;
  cerr<<"Ampl0="<<(ampl0l+ampl0u)/2<<endl;

  fit.set_param_value("bpx",Tb);
  fit.set_param_value("bpy",(ampl0l+ampl0u)/2);
  fit.set_param_value("gamma1",gamma0l);
  fit.set_param_value("gamma2",gamma0u);

  fit.fit();
  //fit.set_opt_method(gsl_simplex<double,vector<double> >());
  fit.fit();
  std::vector<double> p=fit.fit();
  Tb=fit.get_param_value("bpx");
  //std::cout<<"chi="<<fit.get_statistic().eval(p)<<std::endl;
  for(double i=.5;i<12;i*=1.01)
    {
      ofs_result<<i<<"\t0\t0\t"<<fit.eval_model_raw(i,p)<<"\t0\t0\n";
    }


  std::vector<double> mean_p(p.size());
  std::vector<double> mean_p2(p.size());
  int cnt=0;
  for(int n=0;n<100;++n)
    {
      ++cnt;
      cerr<<".";
      double sxxl=0;
      double s1l=0;
      double sxl=0;
      double syl=0;
      double sxyl=0;

      double sxxu=0;
      double s1u=0;
      double sxu=0;
      double syu=0;
      double sxyu=0;

      opt_utilities::default_data_set<double,double> ds1;
      for(size_t i=0;i<ds.size();++i)
	{
	  double x=ds.get_data(i).get_x();
	  double y=ds.get_data(i).get_y();
	  double xl=ds.get_data(i).get_x_lower_err();
	  double xu=ds.get_data(i).get_x_upper_err();
	  double yl=ds.get_data(i).get_y_lower_err();
	  double yu=ds.get_data(i).get_y_upper_err();

	  double new_x=shuffle_data(x,
				    xl,
				    xu);
	  double new_y=shuffle_data(y,
				    yl,
				    yu);

	  ds1.add_data(data<double,double>(new_x,new_y,
					   yl/y*new_y,
					   yu/y*new_y,
					   xl/x*new_x,
					   xu/x*new_x));

	  x=new_x;
	  y=new_y;
	  if(x>Tb)
	    {
	      sxxl+=log(x)*log(x);
	      sxl+=log(x);
	      syl+=log(y);
	      sxyl+=log(y)*log(x);
	      s1l+=1;
	    }
	  else
	    {
	      sxxu+=log(x)*log(x);
	      sxu+=log(x);
	      syu+=log(y);
	      sxyu+=log(y)*log(x);
	      s1u+=1;
	    }
	}
      double Ml=sxxl*s1l-sxl*sxl;
      double Mal=sxyl*s1l-syl*sxl;
      double Mbl=sxxl*syl-sxl*sxyl;
      double k0l=Mal/Ml;
      double b0l=Mbl/Ml;

      double Mu=sxxu*s1u-sxu*sxu;
      double Mau=sxyu*s1u-syu*sxu;
      double Mbu=sxxu*syu-sxu*sxyu;
      double k0u=Mau/Mu;
      double b0u=Mbu/Mu;

      double gamma0l=k0l;
      double gamma0u=k0u;

      double ampl0l=exp(b0l)*pow(Tb,gamma0l);
      double ampl0u=exp(b0u)*pow(Tb,gamma0u);;

      fit.set_param_value("bpx",Tb);
      fit.set_param_value("bpy",(ampl0l+ampl0u)/2);
      fit.set_param_value("gamma1",gamma0l);
      fit.set_param_value("gamma2",gamma0u);


      fit.load_data(ds1);

      fit.fit();
      vector<double> p=fit.fit();
      for(size_t i=0;i<p.size();++i)
	{
	  mean_p[i]+=p[i];
	  mean_p2[i]+=p[i]*p[i];
	}
      //cerr<<fit.get_param_value("gamma1")<<"\t"<<fit.get_param_value("gamma2")<<endl;

    }
  vector<double> std_p(p.size());
  cerr<<endl;
  for(size_t i=0;i<mean_p.size();++i)
    {
      mean_p[i]/=cnt;
      mean_p2[i]/=cnt;
      std_p[i]=std::sqrt(mean_p2[i]-mean_p[i]*mean_p[i]);
      cout<<fit.get_param_info(i).get_name()<<"= "<<p[i]<<" +/- "<<std_p[i]<<endl;
    }
  std::cout<<"Num of sources:"<<ds.size()<<endl;
}
