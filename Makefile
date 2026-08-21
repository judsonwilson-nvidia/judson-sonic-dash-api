.ONESHELL:
SHELL = /bin/bash
.SHELLFLAGS += -e

CXX_FLAGS := -std=c++14 -g -O2
RM := rm -rf
CP := cp -rf
MKDIR := mkdir
MV := mv
PKGNAME := dash_api
LIBNAME := dashapi
LIBDASHAPI := lib$(LIBNAME).so
BUILD_DIR := build
DESTDIR := 
DASH_API_PROTO_DIR := proto
MISC_DIR := misc
PYPKG_DIR := $(MISC_DIR)/pypkg/$(PKGNAME)
TEST_DIR := $(MISC_DIR)/tests
INSTALLED_HEADER_DIR := $(DESTDIR)/usr/include/$(PKGNAME)
INSTALLED_BIN := $(DESTDIR)/usr/bin
INSTALLED_LIB_DIR := $(DESTDIR)/usr/lib
INSTALLED_PYTHON_DIR := $(DESTDIR)/usr/lib/python3/dist-packages/$(PKGNAME)
PYINCLUDE := $(shell python3 -c "import sys; import sysconfig; sys.stdout.write(sysconfig.get_config_var('INCLUDEPY'))")
PYLIBRARY := $(shell python3 -c "import sys; import sysconfig; sys.stdout.write(sysconfig.get_config_var('BLDLIBRARY'))")

all: compile_cpp_proto dashapi.so compile_py_proto swig test

compile_cpp_proto:
	$(MKDIR) -p $(BUILD_DIR)
	protoc -I=$(DASH_API_PROTO_DIR) --cpp_out=$(BUILD_DIR) --experimental_allow_proto3_optional $(DASH_API_PROTO_DIR)/*.proto

dashapi.so: compile_cpp_proto
	g++ $(CXX_FLAGS) -fPIC -shared -o $(BUILD_DIR)/$(LIBDASHAPI) $(wildcard $(BUILD_DIR)/*.pb.cc) $(wildcard $(MISC_DIR)/*.cpp) -lprotobuf

compile_py_proto:
	protoc -I=$(DASH_API_PROTO_DIR) --python_out=$(PYPKG_DIR) --experimental_allow_proto3_optional $(DASH_API_PROTO_DIR)/*.proto
	protoc -I=$(DASH_API_PROTO_DIR) --pyi_out=$(PYPKG_DIR) --experimental_allow_proto3_optional $(DASH_API_PROTO_DIR)/*.proto

swig: compile_cpp_proto
	swig -c++ -python -py3 -outdir $(PYPKG_DIR) -o $(BUILD_DIR)/utils_wrap.cpp $(MISC_DIR)/utils.i
	g++ $(CXX_FLAGS) -shared -I$(PYINCLUDE) -fPIC -I$(MISC_DIR) -o $(PYPKG_DIR)/_utils.so $(MISC_DIR)/utils.cpp $(BUILD_DIR)/utils_wrap.cpp $(wildcard $(BUILD_DIR)/*.pb.cc) -lprotobuf

clean:
	$(RM) $(BUILD_DIR)
	$(RM) $(PYPKG_DIR)/*_pb2.py

install:
	$(MKDIR) -p $(INSTALLED_HEADER_DIR)
	$(CP) $(BUILD_DIR)/*.pb.h $(INSTALLED_HEADER_DIR)
	$(CP) $(MISC_DIR)/*.h $(INSTALLED_HEADER_DIR)

	$(MKDIR) -p $(INSTALLED_LIB_DIR)
	$(CP) $(BUILD_DIR)/$(LIBDASHAPI) $(INSTALLED_LIB_DIR)

	$(MKDIR) -p $(INSTALLED_PYTHON_DIR)
	$(CP) $(PYPKG_DIR)/*.py $(INSTALLED_PYTHON_DIR)
	$(CP) $(PYPKG_DIR)/*.pyi $(INSTALLED_PYTHON_DIR)

	$(CP) $(PYPKG_DIR)/_utils.so $(INSTALLED_PYTHON_DIR)

	$(MKDIR) -p $(INSTALLED_BIN)
	$(CP) $(MISC_DIR)/dash_api_utils $(INSTALLED_BIN)
	chmod +x $(INSTALLED_BIN)/dash_api_utils

uninstall:
	$(RM) $(INSTALLED_HEADER_DIR)
	$(RM) $(INSTALLED_LIB_DIR)/$(LIBDASHAPI)
	$(RM) $(INSTALLED_PYTHON_DIR)

# The Bazel build added test files that this Make build must not pick up. Before those
# commits `python3 -m pytest` collected exactly one file, misc/tests/test_utils.py; the
# scoping below restores that while still discovering any future test added under
# misc/tests/. Run the Bazel ones with `bazel test //...`.
#
# Two distinct problems, hence two mechanisms:
#   * misc/tests/bazel_* -- bazel_python_utils_test.py imports the SWIG extension the way
#     Bazel stages it and fails collection under plain pytest with "ModuleNotFoundError:
#     No module named 'utils'"; bazel_utils_unittest.cpp would be swept into the gtest
#     binary by the wildcard below. Excluded by prefix.
#   * runtime_pkg_test.py -- lives at the repo ROOT and asserts the layout of the packaged
#     Bazel runtime, so it cannot pass outside Bazel and no bazel_ prefix would catch it.
#     Excluded by pointing pytest at $(TEST_DIR) instead of the whole tree.
MAKE_TEST_SRCS := $(filter-out $(TEST_DIR)/bazel_%,$(wildcard $(TEST_DIR)/*.cpp))

test: swig dashapi.so
	g++ -std=c++14 \
		-D PROTO_PATH=\"$(DASH_API_PROTO_DIR)\" \
		-I $(BUILD_DIR) -I $(MISC_DIR) \
		$(MAKE_TEST_SRCS) \
		-L$(BUILD_DIR) -l$(LIBNAME) -lprotobuf -lgtest -lpthread -lboost_system -lboost_filesystem \
		-o $(TEST_DIR)/test
	LD_LIBRARY_PATH=$(BUILD_DIR) $(TEST_DIR)/test
	python3 -m pytest $(TEST_DIR) --ignore-glob='*/bazel_*'

.PHONY: uninstall clean
