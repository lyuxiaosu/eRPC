#Notes:
#1. The make target depends on how eRPC was compiled:
#   * If DTRANSPORT=dpdk, use `make dpdk`
#   * If DTRANSPORT=raw, use `make raw`
#   * If DTRANSPORT=infiniband, use `make infiniband`
LIBS = -lerpc_c_interface -lpthread -lnuma -ldl

CC=clang
CFLAGS=-std=c18 -pthread

# Release Flags
CFLAGS+=-O3 -flto

error:
	@echo "Please choose one of the following targets: infiniband, raw, dpdk, clean"
	@exit 2
infiniband:
	g++ -g -std=c++11 -o server server.cc -I ../src -I ../third_party/asio/include -L ../build $(LIBS) -libverbs -DERPC_INFINIBAND=true
	g++ -g -std=c++11 -o client client.cc -I ../src -I ../third_party/asio/include -L ../build $(LIBS) -libverbs -DERPC_INFINIBAND=true
raw:
	g++ -g -std=c++11 -o server server.cc -I ../src -I ../third_party/asio/include -L ../build $(LIBS) -libverbs -DERPC_RAW=true
	g++ -g -std=c++11 -o client client.cc -I ../src -I ../third_party/asio/include -L ../build $(LIBS) -libverbs -DERPC_RAW=true
dpdk:
	${CC} ${CFLAGS} -o server server.c \
		-Wno-deprecated-declarations \
		-DERPC_DPDK=true -march=native \
		-I ../src -I ../third_party/asio/include -I ../ -I /usr/include/dpdk \
		-L ../build $(LIBS) \
		-Wl,--whole-archive -ldpdk -Wl,--no-whole-archive \
		-lnuma -ldl -libverbs -lmlx4 -lmlx5 -lm -lstdc++

	${CC} ${CFLAGS} -o  client client.c \
		-Wno-deprecated-declarations \
		-DERPC_DPDK=true -march=native \
		-I ../src -I ../../third_party/asio/include -I ../ -I /usr/include/dpdk \
		-L ../build $(LIBS) \
		-Wl,--whole-archive -ldpdk -Wl,--no-whole-archive \
		-lnuma -ldl -libverbs -lmlx4 -lmlx5 -lm -lstdc++
clean:
	rm server client

