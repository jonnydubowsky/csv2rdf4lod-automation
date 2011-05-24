#!/bin/bash
#
# Usage:
#
# Notes:
#   (vload usage: vload [rdf|ttl|nt|nq] [data_file] [graph_uri])

usage_message="usage: `basename $0` [-n] url [-ng named_graph]" 

if [ $# -lt 1 ]; then
   echo $usage_message 
   echo "  -n  : dry run - do not download or load into named graph."
   echo "  url : the URL to retrieve and load into a named graph."
   echo "  -ng : the named graph to place 'url'. (if not provided, -ng == 'url')."
   exit 1
fi

CSV2RDF4LOD_HOME=${CSV2RDF4LOD_HOME:?"not set; source csv2rdf4lod/source-me.sh or see https://github.com/timrdf/csv2rdf4lod-automation/wiki/CSV2RDF4LOD-not-set"}
CSV2RDF4LOD_BASE_URI=${CSV2RDF4LOD_BASE_URI:?"not set; source csv2rdf4lod/source-me.sh or see https://github.com/timrdf/csv2rdf4lod-automation/wiki/CSV2RDF4LOD-not-set"}

dryrun="false"
if [ $1 == "-n" ]; then
   dryrun="true"; shift 
fi

assudo="sudo"
if [ `whoami` == "root" ]; then
   assudo=""
fi

PROV_BASE="http://www.provenanceweb.net/id/"
PROV_BASE="$CSV2RDF4LOD_BASE_URI/id/"

# MD5 this script
curlMD5="md5_`$CSV2RDF4LOD_HOME/bin/util/md5.sh \`which curl\``"

# MD5 this script
myMD5="md5_`$CSV2RDF4LOD_HOME/bin/util/md5.sh $0`"

TEMP="_"`basename $0``date +%s`_$$.response

logID=`java edu.rpi.tw.string.NameFactory`
while [ $# -gt 0 ]; do
   echo
   echo ---------------------------------- pvload ---------------------------------------

   url="$1"
   requestID=`java edu.rpi.tw.string.NameFactory`

   #
   # Grab the file.
   #
   if [ ${dryrun-"."} != "true" ]; then
      $CSV2RDF4LOD_HOME/bin/util/pcurl.sh $url -n $TEMP     # Side affect: creates $TEMP.pml.ttl (will be loaded below).
      unzipped=""
      gunzip -t $TEMP &> /dev/null
      if [ $? -eq 0 ]; then
         unzipped=".unzipped"
         echo "`basename $0`: HTTP response was compressed; uncompressing."
         gunzip -c $TEMP > ${TEMP}${unzipped}
      fi
   else
      echo `basename $CSV2RDF4LOD_HOME/bin/util/pcurl.sh` $url -n $TEMP
      echo "<http://www.w3.org/2002/07/owl#sameAs> <http://www.w3.org/2002/07/owl#sameAs> <http://www.w3.org/2002/07/owl#sameAs> ." > $TEMP
   fi
   usageDateTime=`$CSV2RDF4LOD_HOME/bin/util/dateInXSDDateTime.sh`
   usageDateTimeSlug=`$CSV2RDF4LOD_HOME/bin/util/dateInXSDDateTime.sh coin:slug`

   echo "PVLOAD: url                $url"
   flag=$2
   if [ ${flag:="."} == "-ng" -a $# -ge 2 ]; then # Override the default named graph name (the URL of the source).
      named_graph="$3"
      echo "PVLOAD: -ng             $named_graph"; shift 2
   else
      named_graph="$url"                          # Default to a named graph name of the URL source.
   fi
   echo "PVLOAD: (URL) $url -> (Named Graph) $named_graph"

   #
   # Normalize into ntriples (note, this step is not worth describing in the provenance).
   #
   rapper -g -o ntriples ${TEMP}${unzipped} > ${TEMP}${unzipped}.nt
   if [ ${CSV2RDF4LOD_CONVERT_DEBUG_LEVEL:-"none"} != "finest" ]; then
      rm $TEMP
   fi

   if [ `wc -l ${TEMP}${unzipped}.nt | awk '{print $1}'` -gt 0 ]; then
      # Relative paths.
      sourceUsage="sourceUsage$requestID"
      escapedNG=`echo $named_graph | perl -e 'use URI::Escape; @userinput = <STDIN>; foreach (@userinput) { chomp($_); print uri_escape($_); }'`
      # see https://github.com/timrdf/csv2rdf4lod-automation/wiki/Naming-sparql-service-description's-sd:NamedGraph
      named_graph_global="${CSV2RDF4LOD_PUBLISH_VIRTUOSO_SPARQL_ENDPOINT}?query=PREFIX%20sd%3A%20%3Chttp%3A%2F%2Fwww.w3.org%2Fns%2Fsparql-service-description%23%3E%20CONSTRUCT%20%7B%20%3Fendpoints_named_graph%20%3Fp%20%3Fo%20%7D%20WHERE%20%7B%20GRAPH%20%3C${escapedNG}%3E%20%7B%20%5B%5D%20sd%3Aurl%20%3Chttp%3A%2F%2Flogd.tw.rpi.edu%3A8890%2Fsparql%3E%3B%20sd%3AdefaultDatasetDescription%20%5B%20sd%3AnamedGraph%20%3Fendpoints_named_graph%20%5D%20.%20%3Fendpoints_named_graph%20sd%3Aname%20%3C${escapedNG}%3E%3B%20%3Fp%20%3Fo%20.%20%7D%20%7D"

      echo
      echo "@prefix xsd:        <http://www.w3.org/2001/XMLSchema#> ."                                         > ${TEMP}${unzipped}.load.pml.ttl
      echo "@prefix rdfs:       <http://www.w3.org/2000/01/rdf-schema#> ."                                    >> ${TEMP}${unzipped}.load.pml.ttl
      echo "@prefix dcterms:    <http://purl.org/dc/terms/> ."                                                >> ${TEMP}${unzipped}.load.pml.ttl
      echo "@prefix sioc:       <http://rdfs.org/sioc/ns#> ."                                                 >> ${TEMP}${unzipped}.load.pml.ttl
      echo "@prefix skos:       <http://www.w3.org/2004/02/skos/core#> ."                                     >> ${TEMP}${unzipped}.load.pml.ttl
      echo "@prefix pmlp:       <http://inference-web.org/2.0/pml-provenance.owl#> ."                         >> ${TEMP}${unzipped}.load.pml.ttl
      echo "@prefix pmlj:       <http://inference-web.org/2.0/pml-justification.owl#> ."                      >> ${TEMP}${unzipped}.load.pml.ttl
      echo "@prefix foaf:       <http://xmlns.com/foaf/0.1/> ."                                               >> ${TEMP}${unzipped}.load.pml.ttl
      echo "@prefix sd:         <http://www.w3.org/ns/sparql-service-description#> ."                         >> ${TEMP}${unzipped}.load.pml.ttl
      echo "@prefix oboro:      <http://obofoundry.org/ro/ro.owl#> ."                                         >> ${TEMP}${unzipped}.load.pml.ttl
      echo "@prefix oprov:      <http://openprovenance.org/ontology#> ."                                      >> ${TEMP}${unzipped}.load.pml.ttl
      echo "@prefix hartigprov: <http://purl.org/net/provenance/ns#> ."                                       >> ${TEMP}${unzipped}.load.pml.ttl
      echo                                                                                                    >> ${TEMP}${unzipped}.load.pml.ttl
      $CSV2RDF4LOD_HOME/bin/util/user-account.sh                                                              >> ${TEMP}${unzipped}.load.pml.ttl
      echo                                                                                                    >> ${TEMP}${unzipped}.load.pml.ttl
      echo "<$url>"                                                                                           >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   a pmlp:Source;"                                                                                >> ${TEMP}${unzipped}.load.pml.ttl
      echo "."                                                                                                >> ${TEMP}${unzipped}.load.pml.ttl
      echo                                                                                                    >> ${TEMP}${unzipped}.load.pml.ttl
      echo "<${CSV2RDF4LOD_PUBLISH_VIRTUOSO_SPARQL_ENDPOINT}>"                                                >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   a pmlp:InferenceEngine, pmlp:WebService;"                                                      >> ${TEMP}${unzipped}.load.pml.ttl
      echo "."                                                                                                >> ${TEMP}${unzipped}.load.pml.ttl
      echo                                                                                                    >> ${TEMP}${unzipped}.load.pml.ttl
      echo "<${PROV_BASE}sdService$requestID> a sd:Service;"                                                  >> ${TEMP}${unzipped}.load.pml.ttl
      if [ ${#CSV2RDF4LOD_PUBLISH_VIRTUOSO_SPARQL_ENDPOINT} -gt 0 ]; then
      echo "   sd:url <$CSV2RDF4LOD_PUBLISH_VIRTUOSO_SPARQL_ENDPOINT>;"                                       >> ${TEMP}${unzipped}.load.pml.ttl
      else
      echo "   rdfs:comment \"sd:url omitted b/c \$CSV2RDF4LOD_PUBLISH_VIRTUOSO_SPARQL_ENDPOINT undefined\";" >> ${TEMP}${unzipped}.load.pml.ttl
      fi
      echo "   sd:defaultDatasetDescription ["                                                                >> ${TEMP}${unzipped}.load.pml.ttl
      echo "      a sd:Dataset;"                                                                              >> ${TEMP}${unzipped}.load.pml.ttl
      echo "      sd:namedGraph <$named_graph_global>;"                                                       >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   ];"                                                                                            >> ${TEMP}${unzipped}.load.pml.ttl
      echo "."                                                                                                >> ${TEMP}${unzipped}.load.pml.ttl
      echo                                                                                                    >> ${TEMP}${unzipped}.load.pml.ttl
      echo "<$named_graph_global>"                                                                            >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   a sd:NamedGraph;"                                                                              >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   sd:name <$named_graph>;"                                                                       >> ${TEMP}${unzipped}.load.pml.ttl
      echo "."                                                                                                >> ${TEMP}${unzipped}.load.pml.ttl
      echo                                                                                                    >> ${TEMP}${unzipped}.load.pml.ttl
      echo "<${PROV_BASE}nodeSet${requestID}>"                                                                >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   a pmlj:NodeSet;"                                                                               >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   pmlp:hasCreationDateTime \"${usageDateTime}\"^^xsd:dateTime; # deprecate"                      >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   dcterms:created          \"${usageDateTime}\"^^xsd:dateTime;"                                  >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   pmlj:hasConclusion <${named_graph_global}_${usageDateTimeSlug}>;"                              >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   pmlj:isConsequentOf <${PROV_BASE}infStep${requestID}>;"                                        >> ${TEMP}${unzipped}.load.pml.ttl
      echo "."                                                                                                >> ${TEMP}${unzipped}.load.pml.ttl
      echo "<${named_graph_global}#${usageDateTimeSlug}> skos:broader <${named_graph_global}> ."              >> ${TEMP}${unzipped}.load.pml.ttl
      echo                                                                                                    >> ${TEMP}${unzipped}.load.pml.ttl
      echo "<${PROV_BASE}infStep${requestID}>"                                                                >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   a pmlj:InferenceStep;"                                                                         >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   # TODO: "                                                                                      >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   pmlj:hasAntecedentList ( [ a pmlj:NodeSet; pmlj:hasConclusion <$url>; ] );"                    >> ${TEMP}${unzipped}.load.pml.ttl
      #echo "   pmlj:hasInferenceEngine [];"                                                                  >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   pmlj:hasInferenceRule <http://inference-web.org/registry/MPR/TRIPLE_STORE_LOAD.owl#>;"         >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   oboro:has_agent          `$CSV2RDF4LOD_HOME/bin/util/user-account.sh --cite`;"                 >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   hartigprov:involvedActor `$CSV2RDF4LOD_HOME/bin/util/user-account.sh --cite`;"                 >> ${TEMP}${unzipped}.load.pml.ttl
      echo "   dcterms:date \"`$CSV2RDF4LOD_HOME/bin/util/dateInXSDDateTime.sh`\"^^xsd:dateTime;"             >> ${TEMP}${unzipped}.load.pml.ttl
      echo "."                                                                                                >> ${TEMP}${unzipped}.load.pml.ttl

      echo --------------------------------------------------------------------------------

      vload=${CSV2RDF4LOD_PUBLISH_VIRTUOSO_SCRIPT_PATH:-"/opt/virtuoso/scripts/vload"}
      echo $assudo $vload nt ${TEMP}${unzipped}.nt $named_graph
      if [ ${dryrun-"."} != "true" ]; then #        Actual response (in ntriples syntax).
         $assudo $vload nt ${TEMP}${unzipped}.nt   $named_graph 2>&1 | grep -v "Loading triples into graph" 
         #cat /tmp/virtuoso-tmp/vload.log
      fi
      echo $assudo $vload ttl ${TEMP}.pml.ttl      $named_graph
      if [ ${dryrun-"."} != "true" ]; then # Provenance of response (SourceUsage created by pcurl.sh).
         $assudo $vload ttl ${TEMP}.pml.ttl        $named_graph 2>&1 | grep -v "Loading triples into graph"
         #cat /tmp/virtuoso-tmp/vload.log
      fi
      echo $assudo $vload ttl ${TEMP}.load.pml.ttl  $named_graph
      if [ ${dryrun-"."} != "true" ]; then # Provenance of loading file into the store. TODO: cat ${TEMP}${unzipped}.load.pml.ttl into a pmlp:hasRawString?
         $assudo $vload ttl ${TEMP}${unzipped}.load.pml.ttl   $named_graph 2>&1 | grep -v "Loading triples into graph"             
         #cat /tmp/virtuoso-tmp/vload.log
      fi
      if [ ${CSV2RDF4LOD_CONVERT_DEBUG_LEVEL:-"none"} != "finest" ]; then
         rm -f ${TEMP}${unzipped} ${TEMP}.pml.ttl ${TEMP}${unzipped}.nt ${TEMP}${unzipped}.load.pml.ttl #
      fi
      else
         echo "skipping b/c no triples returned."
      fi
   shift
done
