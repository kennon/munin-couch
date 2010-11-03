# munin-couch #

Munin-couch intends to be a drop-in replacement for munin (the cron job part), polling remote munin nodes and dumping the readings into a couchdb.

The ruby script part should be run on a cron job, it just polls a single munin node and dumps the data into CouchDB.

The second part is (will be) a CouchApp for visualizing the data. The intention of the project is to add more flexibility to the data storage of the Munin readings, and add some fancier JS-based graphing possibilities instead of being tied to RRDTOOL graphs. Another benefit of using CouchDB is due to the built-in replication, it should be trivial to create hierarchies of munin couches, perhaps at varying levels of data retention, etc.
