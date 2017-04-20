#! /usr/bin/env python
transaction = service.transaction()

expid = "/TEST/TEST-PROJECT/DEMO-EXP-SIMPLE"
exp = transaction.getExperiment(expid)

if None == exp:
    exp = transaction.createNewExperiment(expid, "SIRNA_HCS")
    exp.setPropertyValue("DESCRIPTION", "Description of the demo experiment")

dataSet = transaction.createNewDataSet()

dataSet.setDataSetType("UNKNOWN")
dataSet.setExperiment(exp)
transaction.moveFile(incoming.getAbsolutePath(), dataSet)