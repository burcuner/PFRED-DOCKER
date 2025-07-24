FROM centos:7 AS builder

FROM centos:7 AS pfredenv

RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Base.repo && \
    sed -i 's/#baseurl=http:\/\/mirror.centos.org\/centos\/$releasever/baseurl=http:\/\/vault.centos.org\/7.9.2009/g' /etc/yum.repos.d/CentOS-Base.repo && \
    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Vault.repo && \
    sed -i 's/#baseurl=http:\/\/vault.centos.org\/$releasever/baseurl=http:\/\/vault.centos.org\/7.9.2009/g' /etc/yum.repos.d/CentOS-Vault.repo && \
    # Optional: If you see errors about other missing .repo files, you can remove those specific sed commands.
    # The most important ones are Base and potentially Vault.
    yum makecache # Rebuild the cache after changing repo files

RUN mkdir -p /home/pfred/bin

# Install core build dependencies, including readline-devel, texinfo, lapack-devel, blas-devel
RUN yum install -y \
    wget \
    gcc \
    gcc-c++ \
    gcc-gfortran \
    python-devel \
    make \
    which \
    tar \
    readline-devel \
    texinfo \
    lapack-devel \
    blas-devel \
    && yum clean all

ENV PATH="/home/pfred/bin/R2.6.0/bin:${PATH}" \
    PYTHONPATH="/home/pfred/bin/numpy/lib64/python2.6/site-packages:/home/pfred/bin/rpy/lib64/python2.6/site-packages:${PYTHONPATH}"

# Now start downloading and building R, NumPy, and R packages

RUN cd /home && \
    wget --no-check-certificate https://sourceforge.net/projects/numpy/files/NumPy/1.4.1/numpy-1.4.1.tar.gz && \
    wget --no-check-certificate https://cran.r-project.org/src/base/R-2/R-2.6.0.tar.gz && \
    wget --no-check-certificate https://cran.r-project.org/src/base/R-2/R-2.6.0.tar.gz && \
    wget --no-check-certificate https://sourceforge.net/projects/rpy/files/rpy/1.0.2/rpy-1.0.2.tar.gz && \
    wget --no-check-certificate https://cran.r-project.org/src/contrib/Archive/class/class_7.3-1.tar.gz && \
    for f in *.tar.gz; do tar -xvf "$f"; done && \
    wget --no-check-certificate https://cran.r-project.org/src/contrib/Archive/pls/pls_2.1-0.tar.gz && \
    wget --no-check-certificate https://cran.r-project.org/src/contrib/Archive/randomForest/randomForest_4.6-10.tar.gz && \
    wget --no-check-certificate https://cran.r-project.org/src/contrib/Archive/e1071/e1071_1.5-27.tar.gz && \
    cd /home/numpy-1.4.1 && \
    python setup.py build --fcompiler=gnu95 && \
    python setup.py install --prefix=/home/pfred/bin/numpy && \
    cd /home/R-2.6.0 && \
    ./configure --prefix=/home/pfred/bin/R2.6.0 \
                --enable-R-shlib \
                --with-x=no \
                --without-recommended-packages \
                --disable-R-framework \
                --disable-java \
                --without-tcltk \
                --without-nls \
                --without-libintl-plugin \
                --enable-lto=no && \
    make && make install && \
    cd /home/

# Now, install rpy and your R packages
RUN cd /home/rpy-1.0.2 && \
    python setup.py install --prefix=/home/pfred/bin/rpy && \
    cd /home/ && \
    R CMD INSTALL class_7.3-1.tar.gz && \
    R CMD INSTALL pls_2.1-0.tar.gz && \
    R CMD INSTALL randomForest_4.6-10.tar.gz && \
    R CMD INSTALL e1071_1.5-27.tar.gz && \
    # Check the exact paths for numpy and rpy
    # This `mv` sequence is problematic. Let's inspect where things actually land.
    # For now, let's assume they are correctly installed via python setup.py install
    # and simply remove the source directories.
    rm -rf /home/{numpy-1.4.1,rpy-1.0.2,R-2.6.0} && \
    rm -f /home/*.tar.gz # Clean up downloaded archives

# Set the working directory for subsequent instructions and when the container runs

# Add the setup and entrypoint scripts
COPY setup_env.sh /home/pfred/setup_env.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /home/pfred/setup_env.sh

WORKDIR /home/pfred/bin/site-packages

RUN mkdir rpy

# Install java using yum. TODO: Use yum remove to remove unnecessary dependencies

COPY --from=builder /root/.bashrc /root/.bashrc

# Install python3 

RUN cd /home/pfred/ && \
    wget https://repo.anaconda.com/archive/Anaconda3-2021.05-Linux-x86_64.sh && \
    bash Anaconda3-2021.05-Linux-x86_64.sh -b && \
    rm -f Anaconda3-2021.05-Linux-x86_64.sh && \
    echo "export PATH=/root/anaconda3/bin:$PATH" >> ~/.bashrc && \
    source /root/.bashrc && \
    conda install importlib_resources && \
    conda install simplejson

# Create the scripts and scratch directory

RUN source /root/.bashrc && mkdir scripts scratch

# Get libraries from github

COPY ./entrypoint.sh entrypoint.sh

COPY ./setup_env.sh setup_env.sh

RUN chmod a+x entrypoint.sh && chmod a+x setup_env.sh

ENTRYPOINT ["./entrypoint.sh"]

