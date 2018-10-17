WORK_DIR=tmp
BIN=ureplicator
IMAGE=unchartedsky/$(BIN)

all: clean image

build:
	mkdir -p $(WORK_DIR) 

	curl -sL https://github.com/uber/uReplicator/archive/master.tar.gz | tar xz -C $(WORK_DIR)
	
	cd $(WORK_DIR)/uReplicator-master && mvn package -DskipTests

	chmod u+x $(WORK_DIR)/uReplicator-master/bin/pkg/*.sh

image: 
	docker build -t $(IMAGE):latest .

deploy: image
	docker push $(IMAGE):latest

clean:
	@/bin/rm -rf $(WORK_DIR)
