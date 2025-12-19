start job

```
kubectl apply -f ./k6-query-job.yaml
``` 


```
kubectl logs -f job/query-latency-lgtm -n monitoring
```

test vorzeitig beenden:

Hole den Pod-Namen (hast du wahrscheinlich noch in der Variable):  
POD_NAME=$(kubectl get pods -n monitoring -l app=query-benchmark -o jsonpath='{.items[0].metadata.name}')

Sende das Signal:

kubectl exec -n monitoring $POD_NAME -- kill -SIGINT 1

Ergebnisse prüfen:

Sobald der Job beendet ist (Status Completed), liegen die finalen Statistiken auf deinem PVC. Da der Pod dann weg ist, kann man einen kleinen "Helper-Pod" starten, um die Datei zu kopieren oder anzusehen:
Die summary.json direkt anzeigen:
    
kubectl exec -n monitoring $POD_NAME -- cat /results/summary.json

ergebnisse kopieren:
kcp -n monitoring query-latency-lgtm-r4gv7:/results/summary.json ./summary_lgtm.json

job löschen:
kubectl delete job query-latency-lgtm -n monitoring

pvc bereinigen

k delete pvc -n monitoring query-results-pvc