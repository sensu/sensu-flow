# Using sensu-flow with a Sensu Federated Cluster

## Intro
Federation is a commercial feature in the official release of the sensu-backend binary that lets you configure a gateway cluster to act as a command & control node for other Sensu clusters.
You can use sensu-flow in a federated sensu environment in a couple of ways, depending on if you are using Sensu etcd replicators as part of our federation strategy.


## Understanding the role Sensu etcd replicators
The etcd replicator resources let you define what Sensu resource types you would like to replicate to the downstream clusters in a federated Sensu environment. The basic idea is any changes to a resource types configured to be replicated on the gateway will propogate to the downstream clusters.

### Replicating Cluster wide resources
Replicating cluster wide resources (namespaces,cluster-roles,cluster-role-bindings, etc...) are pretty straight forward, and the existing federation guide provides examples of how to do this for cluster wide resources that are required to make downstream api authentication work so the federated dashboard viewer account.  

### Replicating namespaced resources
Any resource type that is namespaced (checks,hooks,handlers,filters,mutators,assets,pipelines,roles,role-bindings, etc...) can only be reliably replicated if the namespce resource type is also replicated.
 
## Example Federated Environment
To get started with sensu-flow in a federated environment, let's pick up where the [the Sensu Federation Guide](https://docs.sensu.io/sensu-go/latest/operations/deploy-sensu/use-federation/) leaves off.
At the end of the federation guide we have 3 Sensu clusters:
* gateway cluster
* alpha cluster
* beta cluster
Each of these with shared jwt token signing certificates needed for trusted api authentication between these clusters.

The [federation guide](https://docs.sensu.io/sensu-go/latest/operations/deploy-sensu/use-federation/) also had us configure the gateway cluster to:
* retrieve alpha and beta event information using `federation/v1/Cluster` resources for the alpha and beta clusters
* create a federation-viewer Sensu user and corresponding ClusterRoleBindings 
* create EtcdReplicator resources to replicate ClusterRoleBindings to the alpha and beta clusters

The federation-viewer user is only defined on the gateway, but the jwt token certificates and the replicated ClusterRoleBindings make it possible to use the gateway's web UI as a single pain (or should I say pane) of glass to see what is happening in the alpha and beta clusters.

Now lets add agents into this federated environment such that each cluster has its own agent sending in events. Okay now how do we use sensu-flow to control what checks these agent runs?


### Adding monitoring workflows without replication.
If you want to control each cluster resources differently, you can do that with sensu-flow just by calling sensu-flow multiple times with different parameters ( once for each cluster). All you have to do is make sure that you have the necessary cluster-wide resources in place to authenticate replicated.

If you are using api-key based auth with sensu-flow, you'll want to make sure that you have created EtcdReplicators for the cluster-wide resource type `core/v2.APIKey` on the gateway cluster for both the alpha and beta servers.
If you are using username/password based auth (deprecated in sensu-flow 0.5.0 in favor of api-key) with sensu-flow you'll need to make sure you have created EtcdReplicators for the cluster-wide resource type `core/v2.User` on the gateway cluster for both the alpha and beta servers.

If you are using any custom ClusterRole or ClusterRoleBindings resources for the user being used  with sensu-flow, you'll need to also create EtcdReplicators for `core/v2.ClusterRole` and `core/v2.ClusterRoleBinding`
    
### Adding replicated monitoring workflows
If you want to make sure all the federated clusters have the same monitoring workflow configurations that are managed by sensu-flow, then its possible to just use sensu-flow communicating with the gateway cluster and rely on EtcdReplicators to replicate resources to the other clusters.  In fact if you have sensu-flow manage the EtcdReplicators resources active on the gateway (as long as sensu-flow has RBAC rights to create/delete those resources)

The key to this workflow is making sure you have EtcdReplicators defined on the gateway for all the resource types you want replicated to the alpha and beta servers.
You can get a full list of of all the resources you might need to replicate using `sensuctl describe-type all`
```
sensuctl describe-type all
         Fully Qualified Name               Short Name           API Version               Type             Namespaced  
────────────────────────────────────── ───────────────────── ─────────────────── ───────────────────────── ─────────────
  authentication/v2.Provider                                  authentication/v2   Provider                  false       
  licensing/v2.LicenseFile                                    licensing/v2        LicenseFile               false       
  store/v1.PostgresConfig                                     store/v1            PostgresConfig            false       
  federation/v1.EtcdReplicator                                federation/v1       EtcdReplicator            false       
  federation/v1.Cluster                                       federation/v1       Cluster                   false       
  secrets/v1.Secret                                           secrets/v1          Secret                    true        
  secrets/v1.Provider                                         secrets/v1          Provider                  false       
  searches/v1.Search                                          searches/v1         Search                    true        
  web/v1.GlobalConfig                                         web/v1              GlobalConfig              false       
  bsm/v1.RuleTemplate                                         bsm/v1              RuleTemplate              true        
  bsm/v1.ServiceComponent                                     bsm/v1              ServiceComponent          true        
  pipeline/v1.SumoLogicMetricsHandler                         pipeline/v1         SumoLogicMetricsHandler   true        
  pipeline/v1.TCPStreamHandler                                pipeline/v1         TCPStreamHandler          true        
  core/v2.Namespace                     namespaces            core/v2             Namespace                 false       
  core/v2.ClusterRole                   clusterroles          core/v2             ClusterRole               false       
  core/v2.ClusterRoleBinding            clusterrolebindings   core/v2             ClusterRoleBinding        false       
  core/v2.User                          users                 core/v2             User                      false       
  core/v2.APIKey                        apikeys               core/v2             APIKey                    false       
  core/v2.TessenConfig                  tessen                core/v2             TessenConfig              false       
  core/v2.Asset                         assets                core/v2             Asset                     true        
  core/v2.CheckConfig                   checks                core/v2             CheckConfig               true        
  core/v2.Entity                        entities              core/v2             Entity                    true        
  core/v2.Event                         events                core/v2             Event                     true        
  core/v2.EventFilter                   filters               core/v2             EventFilter               true        
  core/v2.Handler                       handlers              core/v2             Handler                   true        
  core/v2.HookConfig                    hooks                 core/v2             HookConfig                true        
  core/v2.Mutator                       mutators              core/v2             Mutator                   true        
  core/v2.Pipeline                      pipelines             core/v2             Pipeline                  true        
  core/v2.Role                          roles                 core/v2             Role                      true        
  core/v2.RoleBinding                   rolebindings          core/v2             RoleBinding               true        
  core/v2.Silenced                      silenced              core/v2             Silenced                  true        
```

There are certain resources you probably should not replicate. Such as the federation api resources. Having the alpha cluster try to replicate to beta when the gateway is also replicating to beta is a "bad idea"{tm}
There maybe other resource types that cannot be replicated because they have unique settings for each cluster.  In general the core/v2 resources are likely replicatable, the other resource types are more likely to be cluster specific, especially in a geographically distributed federated environment where different clusters need to use location/region specific secrets/authentication/store provider urls.
 
You will have to use your judgement as to what you want replicated from the gateway to the other clusters. But once you have resource replicators in place, changes made on the gateway by sensu-flow will be replicated to the othe clusters.

Note: namespaced core/v2 resources can only be replicated and used in the other clusters if the `core/v2.Namespace` resource is also replicated.
