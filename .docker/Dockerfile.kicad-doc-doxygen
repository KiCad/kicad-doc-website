FROM kicad/builder:archlinux-builder as build-doxygen-env
USER root
WORKDIR /src
RUN git clone https://github.com/KiCad/kicad-source-mirror.git .

RUN ls
RUN mkdir build && cd build

WORKDIR /src/build

RUN cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DKICAD_USE_OCE=OFF \
    -DKICAD_USE_OCC=ON \
    -DBUILD_GITHUB_PLUGIN=ON \
    -DKICAD_SCRIPTING=ON \
    -DKICAD_SCRIPTING_MODULES=ON \
    -DKICAD_SCRIPTING_ACTION_MENU=ON \
    -DKICAD_SCRIPTING_PYTHON3=ON \
    -DKICAD_SCRIPTING_WXPYTHON=ON \
    -DwxWidgets_CONFIG_EXECUTABLE=/usr/bin/wx-config-gtk3 \
    -DKICAD_SCRIPTING_WXPYTHON_PHOENIX=ON
RUN make doxygen-docs
RUN make doxygen-python


FROM scratch as output-image

COPY --from=build-doxygen-env /src/Documentation/doxygen/html /doxygen-docs_html
COPY --from=build-doxygen-env /src/build/pcbnew/doxygen-python/html /doxygen-python_html
