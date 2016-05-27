#include "plot_reporter.hpp"
#include <cpgplot.h>
#include <cassert>
#include <cstdlib>

plot_reporter::plot_reporter()
{
  const char* pgplot_device=getenv("PGPLOT_DEVICE");
  if(pgplot_device==NULL)
    {
      if (cpgopen("/null") < 1)
	{
	  assert(0);
	}
    }
  else
    {
      if (cpgopen(pgplot_device) < 1)
	{
	  assert(0);
	}
    }
  cpgask(0);
}


plot_reporter::~plot_reporter()
{
  cpgclos();
}


void plot_reporter::init_xyrange(float x1,
				 float x2,
				 float y1,
				 float y2,
				 int axis_flag)
{
  cpgenv(x1, x2, y1, y2, 0, axis_flag);
}


void plot_reporter::plot_line(std::vector<float>& x,std::vector<float>& y)
{
  cpgbbuf();
  cpgline(x.size(),x.data(),y.data());
  cpgebuf();
}

void plot_reporter::plot_err1_dot(std::vector<float>& x,std::vector<float>& y,
				  std::vector<float>& e)
{
  cpgbbuf();
  cpgpt(x.size(),x.data(),y.data(),1);
  cpgerrb(6,x.size(),x.data(),y.data(),e.data(),0);
  cpgebuf();
}


void plot_reporter::plot_err2_dot(std::vector<float>& x,std::vector<float>& y,
				  std::vector<float>& e1,std::vector<float>& e2)
{
  cpgbbuf();
  cpgpt(x.size(),x.data(),y.data(),1);
  cpgerrb(2,x.size(),x.data(),y.data(),e1.data(),0);
  cpgerrb(4,x.size(),x.data(),y.data(),e2.data(),0);
  cpgebuf();
}

plot_reporter pr;
