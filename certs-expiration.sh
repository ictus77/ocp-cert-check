#!/usr/bin/bash


## routers: 

#routers_names=$(cat ./routers)
routers_names=$(oc -n openshift-ingress-operator get ingresscontroller -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

for router_name in $routers_names; 
    do
    # echo $router_name
    mkdir -p ./$router_name
    router_folder="./$router_name"
    router_secret=$(oc -n openshift-ingress-operator get ingresscontroller $router_name -o jsonpath='{.spec.defaultCertificate.name}')
    if [ -n "$router_secret" ]; then
        oc -n openshift-ingress extract "secret/$router_secret" --confirm --to="$router_folder"
    else
        echo "no cert installed" 
        exit 0
    fi

    router_file=$(find "$router_folder" -type f -name "*.crt")
    if [ -z "$router_file" ]; then
        echo "no cert found"
        exit 1
    fi 
    
    csplit --silent --prefix="$router_folder/tmp-" --suffix-format="%d.crt" "$router_file" '/-----BEGIN CERTIFICATE-----/' '{*}'

    rm -f "$router_folder/tmp-0.crt"
    
    i=1
    for file in "$router_folder"/tmp-*.crt; do
        mv "$file" "$router_folder/$router_name-${i}.crt"
        ((i++))
    done
    
    
    for certs in "$router_folder"/*.crt; do
        if [[ "$certs" =~ [0-9]+\.crt$ ]]; then
            echo "🔹 Certificate: $(basename "$certs")"
            openssl x509 -in "$certs" -noout -dates
            echo ""
        fi
    done

done


## API: 
api_folder="./api"
mkdir -p "$api_folder"

api_secret=$(oc get apiserver cluster -o jsonpath='{.spec.servingCerts.namedCertificates[*].servingCertificate.name}' )

if [ -n "$api_secret" ]; then
    #echo "extracting api cert $api_secret"
    oc -n openshift-config extract "secret/$api_secret" --confirm --to="$api_folder"
else
    echo "no cert installed" 
    exit 0
fi


# on local: 
api_file=$(find "$api_folder" -type f -name "*.crt")

if [ -z "$api_file" ]; then
    echo "no cert found"
    exit 1
fi 

csplit --silent --prefix="$api_folder/tmp-" --suffix-format="%d.crt" "$api_file" '/-----BEGIN CERTIFICATE-----/' '{*}'

rm -f "$api_folder/tmp-0.crt"

i=1
for file in "$api_folder"/tmp-*.crt; do
    mv "$file" "$api_folder/api-${i}.crt"
    ((i++))
done


for cert in "$api_folder"/*.crt; do
    if [[ "$cert" =~ [0-9]+\.crt$ ]]; then
        echo "🔹 Certificate: $(basename "$cert")"
        openssl x509 -in "$cert" -noout -dates
        echo ""
    fi
done