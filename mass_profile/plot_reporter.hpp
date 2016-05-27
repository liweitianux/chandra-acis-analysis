#ifndef PLOT_REPORTER_HPP
#define PLOT_REPORTER_HPP
#include <vector>
class plot_reporter
{
private:
  plot_reporter(const plot_reporter&);
  plot_reporter& operator=(const plot_reporter&);
public:
  plot_reporter();
  ~plot_reporter();
  void init_xyrange(float x1,float x2,float y1,float y2,int axis_flag);
  void plot_line(std::vector<float>& x,std::vector<float>& y);
  void plot_err1_dot(std::vector<float>& x,std::vector<float>& y,
		     std::vector<float>& e);
  void plot_err2_dot(std::vector<float>& x,std::vector<float>& y,
		     std::vector<float>& e1,std::vector<float>& e2);
  
};

extern plot_reporter pr;

#endif
