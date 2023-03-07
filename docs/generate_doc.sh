#!/usr/bin/env bash

if [[ -z "${PROJECT_NAME}" ]]; then
    echo "'PROJECT_NAME' environment variable must be defined"
fi

####################################################################################################
# Functions
####################################################################################################
function usage(){
    cat ${project_doc_dir}/README.md
    echo "(content of ${project_doc_dir}/README.md) "
}

function clean(){
    if [ -d "${doc_build_dir}" ]||[ -d "${doc_output_dir_prefix}" ]; then
        read -p "Doc directory already exists, replace it ? ([yes]/no) " answer
        if [[ -z "${answer}" ]]||[[ "${answer}" == "y"* ]]; then
            rm -rf ${doc_build_dir} ${doc_output_dir_prefix}
        else
            exit 0
        fi
    fi
}

function add_sources(){
    local name=$1
    shift
    local item=$1
    shift
    local root_dir=$1
    shift
    if [[ -z "${source_directories}" ]]; then
        source_directories=( $item )
    else
        source_directories+=( $item )
    fi

    cd ${project_root_dir}
    local args="$@ --tocfile ${item} -q --doc-project ${name} --separate"
    local args="${args} --output-dir ${doc_build_dir}/${item} ${root_dir}/${item}"
    sphinx-apidoc ${args}
    if (( $? > 0 )); then
        echo "failed: sphinx-apidoc ${args}"
        exit 1
    fi
}

function generate_sphinx(){
    cd ${doc_build_dir}
    local options="--no-makefile --no-batchfile --quiet --no-sep"
    local options="${options} --extensions=sphinx.ext.napoleon --extensions=sphinx_rtd_theme --extensions=myst_parser --extensions=numpydoc"
    local options="${options} --ext-autodoc --ext-intersphinx --ext-doctest --ext-viewcode"
    sphinx-quickstart --project ${project_name} -v ${project_version} --author ${project_author} ${options} .
    if (( $? > 0 )); then
        echo "failed: sphinx-quickstart --project ${project_name} -v ${project_version} --author ${project_author} ${options} ."
        exit 1
    fi

    # Custom generated files
    # add sources in toctree
    for module in ${source_directories[@]}; do
        sed -i 's/Contents\:/Contents\:\n\n   '${module}'\/'${module}'.rst/' ${doc_build_dir}/index.rst
    done

    sed -i 's/Contents\:/Contents\:\n\n   md_doc\/introduction.md/' ${doc_build_dir}/index.rst

    # use a rtd theme
    sed -i 's/alabaster/sphinx_rtd_theme/' ${doc_build_dir}/conf.py

    echo "${custom_conf_options}" >> ${doc_build_dir}/conf.py
    echo "intersphinx_mapping['mpi4py'] = ('https://mpi4py.readthedocs.io/en/stable/', None)" >> ${doc_build_dir}/conf.py
    echo "intersphinx_mapping['numpy'] = ('https://docs.scipy.org/doc/numpy/', None)" >> ${doc_build_dir}/conf.py
    echo "autodoc_mock_imports = ['medcoupling']" >> ${doc_build_dir}/conf.py
}

function build_html(){
    local options="-j $(nproc) -b ${sphinx_builder} -q"
    cp -r ${project_doc_dir}/md_doc ${doc_build_dir}
    sphinx-build ${options} ${doc_build_dir} ${doc_output_dir}
}

####################################################################################################
# Execution
####################################################################################################

# root directory
project_doc_dir="$( cd "$( dirname "${0}" )" &> /dev/null && pwd )"
project_root_dir="$( cd "$( dirname "${project_doc_dir}" )" &> /dev/null && pwd )"

# current directory
current_dir="${PWD}"

#############################
# default variables
#############################
project_name="${PROJECT_NAME}"
project_author="CEA"
project_version=$(python3 -c "import ${PROJECT_NAME}; print(${PROJECT_NAME}.__version__)")

doc_build_dir=${project_doc_dir}/${project_name}-sphinx-sources
doc_output_dir_prefix=${project_doc_dir}/${project_name}-doc

shpinx_do_all=true
sphinx_clean=false
sphinx_build=false
sphinx_init=false
sphinx_builder="html"

custom_conf_options="
autodoc_default_options = {
    'members': True,
    'member-order': 'bysource',
    'special-members': '__init__',
    'undoc-members': True,
    'exclude-members': '__weakref__'
}
numpydoc_class_members_toctree = False
"

#############################
# cli
#############################

# Get options
options=$(getopt \
  --longoptions help,clean,init,build,latex \
  --options h \
  --name "$(basename "$0")" \
  -- "$@"
)
eval set -- "${options}"

# Parsing options
while true; do
    case "$1" in
        --clean)
            sphinx_clean=true
            shpinx_do_all=false
            shift
            ;;
        --init)
            sphinx_init=true
            shpinx_do_all=false
            shift
            ;;
        --build)
            sphinx_build=true
            shpinx_do_all=false
            shift
            ;;
        --latex)
            sphinx_builder="latex"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
    esac
done

#############################
# Execution
#############################

doc_output_dir=${project_doc_dir}/${project_name}-doc/${sphinx_builder}

if [[ "${sphinx_clean}" == "true" ]]||[[ "${shpinx_do_all}" == "true" ]]; then
    clean
fi
if [[ "${sphinx_init}" == "true" ]]||[[ "${shpinx_do_all}" == "true" ]]; then
    add_sources Sources src ${project_root_dir}
    # add_sources MedCoupling medcoupling.py /home/prerequis_codes-public/install/lin-x86-64-cen7/native/SALOME-9.8.0/MEDCOUPLING/lib/python3.6/site-packages
    generate_sphinx
fi
if [[ "${sphinx_build}" == "true" ]]||[[ "${shpinx_do_all}" == "true" ]]; then
    build_html
fi

echo "
Doc is produced in ${doc_output_dir}/index.html directory

    file://${doc_output_dir}/index.html
"