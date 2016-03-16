FROM centos/ruby-22-centos7

RUN scl enable rh-ruby22 -- gem install ascii_binder

WORKDIR /opt/app-root/src/docs
LABEL url http://www.asciibinder.org \
      summary a documentation system built on Asciidoctor \
      description AsciiBinder is for documenting versioned, interrelated projects. Run this container from the documentation repository, which is mounted into the container. You may need to run chmod 1001:1001 <asciidoc_repo_dir> \
      RUN docker run -it --rm \
          -v `pwd`:/opt/app-root/src/docs \
          IMAGE

ENV LANG=en_US.UTF-8
CMD asciibinder package
