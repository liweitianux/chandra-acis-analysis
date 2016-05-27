targets=fit_nfw_sbp fit_dbeta_sbp fit_beta_sbp fit_direct_beta calc_distance fit_wang2012_model fit_nfw_mass calc_lx fit_mt_pl fit_lt_pl fit_mt_bpl fit_lt_bpl cooling_time calc_lx_dbeta calc_lx_beta
target:$(targets) py

LIB_PGPLOT_PATH="`ls`"
LIB_PGPLOT=plot_reporter.cpp -lcpgplot -lpgplot -lX11 -lgfortran

py:
	chmod a+x *.py

fit_nfw_sbp:fit_nfw_sbp.cpp nfw_ne.hpp projector.hpp spline.h vchisq.hpp plot_reporter.hpp plot_reporter.cpp
	g++ $< -o $@ -I ../opt_utilities -O3 `if [ -e pgplot_path.txt ]; then grep LIB pgplot_path.txt|awk '{print "-L" $$2}'; fi` `if [ -e pgplot_path.txt ]; then grep INC pgplot_path.txt|awk '{print "-I" $$2}'; fi` $(LIB_PGPLOT)

fit_dbeta_sbp:fit_dbeta_sbp.cpp beta_cfg.cpp beta_cfg.hpp constrained_dbeta.hpp projector.hpp spline.h vchisq.hpp plot_reporter.hpp plot_reporter.cpp report_error.hpp report_error.cpp
	g++ -o $@ $< report_error.cpp beta_cfg.cpp -I ../opt_utilities -O3 `if [ -e pgplot_path.txt ]; then grep LIB pgplot_path.txt|awk '{print "-L" $$2}'; fi` `if [ -e pgplot_path.txt ]; then grep INC pgplot_path.txt|awk '{print "-I" $$2}'; fi` $(LIB_PGPLOT)

fit_beta_sbp:fit_beta_sbp.cpp beta_cfg.cpp beta_cfg.hpp beta.hpp projector.hpp spline.h vchisq.hpp plot_reporter.hpp plot_reporter.cpp dump_fit_qdp.cpp dump_fit_qdp.hpp
	g++ -o $@ $< dump_fit_qdp.cpp beta_cfg.cpp report_error.cpp -I ../opt_utilities -O3 `if [ -e pgplot_path.txt ]; then grep LIB pgplot_path.txt|awk '{print "-L" $$2}'; fi` `if [ -e pgplot_path.txt ]; then grep INC pgplot_path.txt|awk '{print "-I" $$2}'; fi` $(LIB_PGPLOT)

fit_wang2012_model:fit_wang2012_model.cpp wang2012_model.hpp chisq.hpp plot_reporter.hpp plot_reporter.cpp
	g++ $< -o $@ -I ../opt_utilities -O3 `if [ -e pgplot_path.txt ]; then grep LIB pgplot_path.txt|awk '{print "-L" $$2}'; fi` `if [ -e pgplot_path.txt ]; then grep INC pgplot_path.txt|awk '{print "-I" $$2}'; fi` $(LIB_PGPLOT)

fit_nfw_mass:fit_nfw_mass.cpp nfw.hpp chisq.hpp plot_reporter.hpp plot_reporter.cpp
	g++ $< -o $@ -I ../opt_utilities -O3 `if [ -e pgplot_path.txt ]; then grep LIB pgplot_path.txt|awk '{print "-L" $$2}'; fi` `if [ -e pgplot_path.txt ]; then grep INC pgplot_path.txt|awk '{print "-I" $$2}'; fi` $(LIB_PGPLOT)


fit_direct_beta:fit_direct_beta.cpp plot_reporter.hpp plot_reporter.cpp
	g++ $< -o $@ -I ../opt_utilities -O3 `if [ -e pgplot_path.txt ]; then grep LIB pgplot_path.txt|awk '{print "-L" $$2}'; fi` `if [ -e pgplot_path.txt ]; then grep INC pgplot_path.txt|awk '{print "-I" $$2}'; fi` $(LIB_PGPLOT)

calc_lx:calc_lx.cpp plot_reporter.hpp plot_reporter.cpp calc_distance.h calc_distance.cc
	g++ -o $@ $< calc_distance.cc -I ../opt_utilities -O3 `if [ -e pgplot_path.txt ]; then grep LIB pgplot_path.txt|awk '{print "-L" $$2}'; fi` `if [ -e pgplot_path.txt ]; then grep INC pgplot_path.txt|awk '{print "-I" $$2}'; fi` $(LIB_PGPLOT)

calc_lx_dbeta:calc_lx_dbeta.cpp beta_cfg.cpp beta_cfg.hpp constrained_dbeta.hpp projector.hpp spline.h vchisq.hpp plot_reporter.hpp plot_reporter.cpp report_error.hpp report_error.cpp
	g++ -o $@ $< report_error.cpp beta_cfg.cpp -I ../opt_utilities -O3 `if [ -e pgplot_path.txt ]; then grep LIB pgplot_path.txt|awk '{print "-L" $$2}'; fi` `if [ -e pgplot_path.txt ]; then grep INC pgplot_path.txt|awk '{print "-I" $$2}'; fi` $(LIB_PGPLOT)

calc_lx_beta:calc_lx_beta.cpp beta_cfg.cpp beta_cfg.hpp beta.hpp projector.hpp spline.h vchisq.hpp plot_reporter.hpp plot_reporter.cpp dump_fit_qdp.cpp dump_fit_qdp.hpp
	g++ -o $@ $< dump_fit_qdp.cpp beta_cfg.cpp report_error.cpp -I ../opt_utilities -O3 `if [ -e pgplot_path.txt ]; then grep LIB pgplot_path.txt|awk '{print "-L" $$2}'; fi` `if [ -e pgplot_path.txt ]; then grep INC pgplot_path.txt|awk '{print "-I" $$2}'; fi` $(LIB_PGPLOT)

calc_distance:call_calc_distance.cc calc_distance.cc calc_distance.h adapt_trapezoid.h
	g++ call_calc_distance.cc calc_distance.cc -o $@ -O3

fit_mt_pl:fit_mt_pl.cpp
	g++ $< -o $@ -O3 -I ../opt_utilities

fit_lt_pl:fit_lt_pl.cpp
	g++ $< -o $@ -O3 -I ../opt_utilities

fit_mt_bpl:fit_mt_bpl.cpp
	g++ $< -o $@ -O3 -I ../opt_utilities

fit_lt_bpl:fit_lt_bpl.cpp
	g++ $< -o $@ -O3 -I ../opt_utilities

cooling_time:cooling_time.cpp
	g++ $< -o $@ -O3

clean:
	rm -f $(targets)
