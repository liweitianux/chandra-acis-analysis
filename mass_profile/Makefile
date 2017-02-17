#
# Makefile for `chandra-acis-analysis/mass_profile` tools
#
# Junhua GU
# Weitian LI
# 2016-06-07
#


CXX ?= g++
CXXFLAGS += -Wall
CXXFLAGS += -Werror

ifdef OPENMP
	CXXFLAGS += -fopenmp
endif

ifdef DEBUG
	CXXFLAGS += -g
else
	CXXFLAGS += -O2
endif

OPT_UTIL_INC ?= -I../opt_utilities

TARGETS= fit_dbeta_sbp fit_beta_sbp fit_wang2012_model \
		fit_nfw_mass calc_lx_dbeta calc_lx_beta
HEADERS= projector.hpp spline.hpp vchisq.hpp

all: $(TARGETS)

# NOTE:
# Object/source files should placed *before* libraries (order matters)

fit_dbeta_sbp: fit_dbeta_sbp.o beta_cfg.o report_error.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC)

fit_beta_sbp: fit_beta_sbp.o beta_cfg.o dump_fit_qdp.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC)

fit_wang2012_model: fit_wang2012_model.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC)

fit_nfw_mass: fit_nfw_mass.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC)

calc_lx_dbeta: calc_lx_dbeta.o beta_cfg.o report_error.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC)

calc_lx_beta: calc_lx_beta.o beta_cfg.o dump_fit_qdp.o
	$(CXX) $(CXXFLAGS) $^ -o $@ $(OPT_UTIL_INC)


fit_dbeta_sbp.o: fit_dbeta_sbp.cpp constrained_dbeta.hpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC)

fit_beta_sbp.o: fit_beta_sbp.cpp beta.hpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC)

fit_wang2012_model.o: fit_wang2012_model.cpp wang2012_model.hpp chisq.hpp
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC)

fit_nfw_mass.o: fit_nfw_mass.cpp nfw.hpp chisq.hpp
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC)

calc_lx_dbeta.o: calc_lx_dbeta.cpp constrained_dbeta.hpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC)

calc_lx_beta.o: calc_lx_beta.cpp beta.hpp $(HEADERS)
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC)

beta_cfg.o: beta_cfg.cpp beta_cfg.hpp
	$(CXX) $(CXXFLAGS) -c $<

report_error.o: report_error.cpp report_error.hpp
	$(CXX) $(CXXFLAGS) -c $<

dump_fit_qdp.o: dump_fit_qdp.cpp dump_fit_qdp.hpp
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< $(OPT_UTIL_INC)


clean:
	rm -f *.o $(TARGETS)
