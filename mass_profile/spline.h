#ifndef SPLINE_H
#define SPLINE_H

#include <vector>
#include <cstdlib>
#include <cassert>
#include <cmath>
#include <limits>

template <typename T>
class spline
{
public:
  std::vector<T> x_list;
  std::vector<T> y_list;
  std::vector<T> y2_list;

public:
  void push_point(T x,T y)
  {
    if(!x_list.empty())
      {
	assert(x>*(x_list.end()-1));
      }
    x_list.push_back(x);
    y_list.push_back(y);
  }

  T get_value(T x)
  {
    if(x<=x_list[0])
      {
	return y_list[0];
      }
    if(x>=x_list.back())
      {
	return y_list.back();
      }
    assert(x_list.size()==y2_list.size());
    assert(x>x_list[0]);
    assert(x<x_list.back());
    int n1,n2;
    n1=0;
    n2=x_list.size()-1;
    while((n2-n1)!=1)
      {
	//cerr<<n1<<"\t"<<n2<<endl;
	if(x_list[n1+1]<=x)
	  {
	    n1++;
	  }
	if(x_list[n2-1]>x)
	  {
	    n2--;
	  }
      }
    T h=x_list[n2]-x_list[n1];
    double a=(x_list[n2]-x)/h;
    double b=(x-x_list[n1])/h;
    return a*y_list[n1]+b*y_list[n2]+((a*a*a-a)*y2_list[n1]+
				      (b*b*b-b)*y2_list[n2])*(h*h)/6.;

  }

  void gen_spline(T y2_0,T y2_N)
  {
    int n=x_list.size();
    y2_list.resize(0);
    y2_list.resize(x_list.size());
    std::vector<T> u(x_list.size());
    if(std::abs(y2_0)<std::numeric_limits<T>::epsilon())
      {
	y2_list[0]=0;
	u[0]=0;
      }
    else
      {
	y2_list[0]=-.5;
	u[0]=(3./(x_list[1]-x_list[0]))*((y_list[1]-y_list[0])/(x_list[1]-x_list[0])-y2_0);
      }
    for(int i=1;i<n-1;++i)
      {
	double sig=(x_list[i]-x_list[i-1])/(x_list[i+1]-x_list[i-1]);
	double p=sig*y2_list[i-1]+2.;
	y2_list[i]=(sig-1.)/p;
	u[i]=(y_list[i+1]-y_list[i])/(x_list[i+1]-x_list[i])
	  -(y_list[i]-y_list[i-1])/(x_list[i]-x_list[i-1]);
	u[i]=(6.*u[i]/(x_list[i+1]-x_list[i-1])-sig*u[i-1])/p;
      }
    double qn,un;
    if(std::abs(y2_N)<std::numeric_limits<T>::epsilon())
      {
	qn=un=0;
      }
    else
      {
	qn=.5;
	un=(3./(x_list[n-1]-x_list[n-2]))*(y2_N-(y_list[n-1]-y_list[n-2])/(x_list[n-1]-x_list[n-2]));

      }
    y2_list[n-1]=(un-qn*u[n-2])/(qn*y2_list[n-2]+1.);
    for(int i=n-2;i>=0;--i)
      {
	y2_list[i]=y2_list[i]*y2_list[i+1]+u[i];
      }
  }

};

#endif  /* SPLINE_H */
