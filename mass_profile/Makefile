#
# Makefile for `chandra-acis-analysis/mass_profile` tools
#
# Junhua GU
# Weitian LI
# 2016-06-07
#


CXX ?= g++
#CXXFLAGS += -Wall -Werror
CXXFLAGS += -Wall

ifdef OPENMP
	CXXFLAGS += -fopenmp
endif

ifdef DEBUG
	CXXFLAGS += -g
else
	CXXFLAGS += -O2
endif

OPT_UTIL_INC ?= -I../opt_utilities
PGPLOT_INC= -I$(HEADAS)/include
PGPLOT_LIB= -L. -lcpgplot -lpgplot -lX11 -lgfortran

TARGETS= fit_nfw_sbp fit_dbeta_sbp fit_beta_sbp \
		fit_direct_beta calc_distance fit_wang2012_model \
		fit_nfw_mass calc_lx fit_mt_pl fit_lt_pl fit_mt_bpl \
		fit_lt_bpl cooling_time calc_lx_dbeta calc_lx_beta
HEADERS= projector.hpp spline.hpp vchisq.hpp

all: pgplot $(TARGETS)

pgplot: libcpgplot.a libpgplot.a

libcpgplot.a:
ifdef HEADAS
	ln -s $(HEADAS)/lib/libcpgplot*.a ./$@
else
	$(error HEASoft not initialized)
endif

libpgplot.a:
ifdef HEADAS
	ln -s $(HEADAS)/lib/libpgplot*.a  ./$@
else
	$(error HEASoft not initialized)
endif

# NOTE:
# Object/source files should placed *before* libraries (order matters)
fit_nfw_sbp: fit_nfw_sbp.o plot_reporter.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC) $(PGPLOT_INC) $(PGPLOT_LIB)

fit_dbeta_sbp: fit_dbeta_sbp.o beta_cfg.o report_error.o plot_reporter.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC) $(PGPLOT_INC) $(PGPLOT_LIB)

fit_beta_sbp: fit_beta_sbp.o beta_cfg.o dump_fit_qdp.o plot_reporter.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC) $(PGPLOT_INC) $(PGPLOT_LIB)

fit_wang2012_model: fit_wang2012_model.o plot_reporter.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC) $(PGPLOT_INC) $(PGPLOT_LIB)

fit_nfw_mass: fit_nfw_mass.o plot_reporter.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC) $(PGPLOT_INC) $(PGPLOT_LIB)

fit_direct_beta: fit_direct_beta.o plot_reporter.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC) $(PGPLOT_INC) $(PGPLOT_LIB)

calc_lx: calc_lx.o calc_distance.o plot_reporter.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC) $(PGPLOT_INC) $(PGPLOT_LIB)

calc_lx_dbeta: calc_lx_dbeta.o beta_cfg.o report_error.o plot_reporter.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC) $(PGPLOT_INC) $(PGPLOT_LIB)

calc_lx_beta: calc_lx_beta.o beta_cfg.o dump_fit_qdp.o plot_reporter.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC) $(PGPLOT_INC) $(PGPLOT_LIB)

calc_distance: calc_distance_main.o calc_distance.o
	$(CXX) $(CXXFLAGS) -o $@ $^

fit_mt_pl: fit_mt_pl.cpp
	$(CXX) $(CXXFLAGS) $< -o $@ $(OPT_UTIL_INC)

fit_lt_pl: fit_lt_pl.cpp
	$(CXX) $(CXXFLAGS) $< -o $@ $(OPT_UTIL_INC)

fit_mt_bpl: fit_mt_bpl.cpp
	$(CXX) $(CXXFLAGS) $< -o $@ $(OPT_UTIL_INC)

fit_lt_bpl: fit_lt_bpl.cpp
	$(CXX) $(CXXFLAGS) $< -o $@ $(OPT_UTIL_INC)

cooling_time: cooling_time.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<


fit_nfw_sbp.o: fit_nfw_sbp.cpp nfw_ne.hpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC) $(PGPLOT_INC)

fit_dbeta_sbp.o: fit_dbeta_sbp.cpp constrained_dbeta.hpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC) $(PGPLOT_INC)

fit_beta_sbp.o: fit_beta_sbp.cpp beta.hpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC) $(PGPLOT_INC)

fit_wang2012_model.o: fit_wang2012_model.cpp wang2012_model.hpp chisq.hpp
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC) $(PGPLOT_INC)

fit_nfw_mass.o: fit_nfw_mass.cpp nfw.hpp chisq.hpp
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC) $(PGPLOT_INC)

calc_lx_dbeta.o: calc_lx_dbeta.cpp constrained_dbeta.hpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC) $(PGPLOT_INC)

calc_lx_beta.o: calc_lx_beta.cpp beta.hpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC) $(PGPLOT_INC)

plot_reporter.o: plot_reporter.cpp plot_reporter.hpp
	$(CXX) $(CXXFLAGS) -c $< $(PGPLOT_INC)

beta_cfg.o: beta_cfg.cpp beta_cfg.hpp
	$(CXX) $(CXXFLAGS) -c $<

report_error.o: report_error.cpp report_error.hpp
	$(CXX) $(CXXFLAGS) -c $<

dump_fit_qdp.o: dump_fit_qdp.cpp dump_fit_qdp.hpp
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC)

calc_distance.o: calc_distance.cc calc_distance.h adapt_trapezoid.h
	$(CXX) $(CXXFLAGS) -c $<

%.o: %.cc
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC)


clean:
	rm -f *.o $(TARGETS)

cleanall: clean
	rm -f libpgplot.a libcpgplot.a
