* GEMreports.gms


* Last modified by Dr Phil Bishop, 07/10/2011 (imm@ea.govt.nz)



** Note that reportDomain is a single solve and is manually assigned as such. The writing of summary results will
** not work if reportDomain contains more than one solve.


$ontext
 This program generates GEM reports - human-readable files, files to be read by other applications for further processing,
 or pictures. It is to be invoked subsequent to GEMsolve. It does "not" start from GEMdeclarations.g00. All symbols required
 in this program are declared here. Set membership and data values are imported from the default (or base case) run version
 input GDX file or merged GDX files.

 Code sections:
  1. Declare required symbols and load data.
  2. Perform the calculations to be reported.
  3. Write out the external files.
$offtext

option seed = 101 ;
$include GEMsettings.inc
$include GEMpathsAndFiles.inc
$offupper offsymxref offsymlist offuellist offuelxref onempty inlinecom { } eolcom !

* Declare output files to be created by GEMreports.
Files
  plotBat        / "%OutPath%\%runName%\Archive\GEMplots.bat" /
  plotResults    / "%OutPath%\%runName%\Processed files\Results to be plotted - %runName%.csv" /
  summaryResults / "%OutPath%\%runName%\Summary results - %runName%.csv" /
  capacityPlant  / "%OutPath%\%runName%\Processed files\Capacity by plant and year (net of retirements) - %runName%.csv" /
  genPlant       / "%OutPath%\%runName%\Processed files\Generation and utilisation by plant - %runName%.csv" /
  genPlantYear   / "%OutPath%\%runName%\Processed files\Generation and utilisation by plant (annually) - %runName%.csv" /
  variousAnnual  / "%OutPath%\%runName%\Processed files\Various annual results - %runName%.csv" /
  ;

plotBat.lw = 0 ;
plotResults.pc = 5 ;     plotResults.pw = 999 ;
summaryResults.pc = 5 ;  summaryResults.pw = 999 ;
capacityPlant.pc = 5 ;   capacityPlant.pw = 999 ;
genPlant.pc = 5 ;        genPlant.pw = 999 ;
genPlantYear.pc = 5 ;    genPlantYear.pw = 999 ;
variousAnnual.pc = 5 ;   variousAnnual.pw = 999 ;



*===============================================================================================
* 1. Declare required symbols and load data.

* Declare and initialise hard-coded sets - copied from GEMdeclarations.
Sets
  steps             'Steps in an experiment'              / timing     'Solve the timing problem, i.e. timing of new generation/or transmission investment'
                                                            reopt      'Solve the re-optimised timing problem (generally with a drier hydro sequence) while allowing peakers to move'
                                                            dispatch   'Solve for the dispatch only with investment timing fixed'  /
  hydroSeqTypes     'Types of hydro sequences to use'     / Same       'Use the same sequence of hydro years to be used in every modelled year'
                                                            Sequential 'Use a sequentially developed mapping of hydro years to modelled years' /
  ild               'Islands'                             / ni         'North Island'
                                                            si         'South Island' /
  aggR              'Aggregate regional entities'         / ni         'North Island'
                                                            si         'South Island'
                                                            nz         'New Zealand' /
  col               'RGB color codes'                     / 0 * 256 /
  ;

* Initialise set y with values from GEMsettings.inc.
Set y 'Modelled calendar years' / %firstYear% * %lastYear% / ;

* Declare the fundamental sets required for reporting.
Sets
  k                 'Generation technologies'
  f                 'Fuels'
  g                 'Generation plant'
  s                 'Shortage or VOLL plants'
  o                 'Owners of generating plant'
  i                 'Substations'
  r                 'Regions'
  e                 'Zones'
  t                 'Time periods (within a year)'
  lb                'Load blocks'
  rc                'Reserve classes'
  hY                'Hydrology output years' ;

Alias (i,ii), (r,rr), (col,red,green,blue) ;

* Declare the selected subsets and mapping sets required for reporting.
Sets
  techColor(k,red,green,blue)      'RGB color mix for technologies - to pass to plotting applications'
*  fuelColor(f,red,green,blue)     'RGB color mix for fuels - to pass to plotting applications'
*  fuelGrpcolor(fg,red,green,blue) 'RGB color mix for fuel groups - to pass to plotting applications'
  firstPeriod(t)                   'First time period (i.e. period within the modelled year)'
  thermalFuel(f)                   'Thermal fuels'
  nwd(r,rr)                        'Northward direction of flow on Benmore-Haywards HVDC'
  swd(r,rr)                        'Southward direction of flow on Benmore-Haywards HVDC'
  paths(r,rr)                      'All valid transmission paths'
  mapg_k(g,k)                      'Map technology types to generating plant'
  mapg_f(g,f)                      'Map fuel types to generating plant'
  mapg_o(g,o)                      'Map plant owners to generating plant'
  mapg_r(g,r)                      'Map regions to generating plant'
  mapg_e(g,e)                      'Map zones to generating plant'
  mapAggR_r(aggR,r)                'Map the regions to the aggregated regional entities (this is primarily to facilitate reporting)'
  isIldEqReg(ild,r)                'Figure out if the region labels are identical to the North and South island labels (a reporting facilitation device)' 
  demandGen(k)                     'Demand side technologies modelled as generation'
  sigen(g)                         'South Island generation plant' ;

* Load set membership from the GDX file containing the default or base case run version.
$gdxin "%OutPath%\%runName%\Input data checks\Selected prepared input data - %runName%_%baseRunVersion%.gdx"
$loaddc k f g s o i r e t lb rc hY
$loaddc firstPeriod thermalFuel nwd swd paths mapg_k mapg_f mapg_o mapg_r mapg_e mapAggR_r isIldEqReg demandGen sigen
$loaddc techColor
* fuelColor fuelGrpColor

* Need steps for the non-free reserves stuff - this may yet get deleted!
Set stp 'Steps'  / stp1 * stp5 / ;

* Include GEMstochastic - can't do this until hY and hydroSeqTypes are loaded 
$include GEMstochastic.inc
Alias(scenarios,scen), (scenarioSets,scenSet) ;

* Declare and load the parameters (variable levels and marginals) to be found in the merged 'all_ReportOutput' GDX file.
Parameters
  s_TOTALCOST(runVersions,experiments,steps,scenSet)                          'Discounted total system costs over all modelled years, $m (objective function value)'
  s_TX(runVersions,experiments,steps,scenSet,r,rr,y,t,lb,scen)                 'Transmission from region to region in each time period, MW (-ve reduced cost equals s_TXprice???)'
  s_REFURBCOST(runVersions,experiments,steps,scenSet,g,y)                      'Annualised generation plant refurbishment expenditure charge, $'
  s_BUILD(runVersions,experiments,steps,scenSet,g,y)                           'New capacity installed by generating plant and year, MW'
  s_CAPACITY(runVersions,experiments,steps,scenSet,g,y)                        'Cumulative nameplate capacity at each generating plant in each year, MW'
  s_TXCAPCHARGES(runVersions,experiments,steps,scenSet,r,rr,y)                 'Cumulative annualised capital charges to upgrade transmission paths in each modelled year, $m'
  s_GEN(runVersions,experiments,steps,scenSet,g,y,t,lb,scen)                   'Generation by generating plant and block, GWh'
  s_VOLLGEN(runVersions,experiments,steps,scenSet,s,y,t,lb,scen)               'Generation by VOLL plant and block, GWh'
  s_RESV(runVersions,experiments,steps,scenSet,g,rc,y,t,lb,scen)               'Reserve energy supplied, MWh'
  s_RESVVIOL(runVersions,experiments,steps,scenSet,rc,ild,y,t,lb,scen)         'Reserve energy supply violations, MWh'
  s_RESVCOMPONENTS(runVersions,experiments,steps,scenSet,r,rr,y,t,lb,scen,stp) 'Non-free reserve components, MW'
  s_RENNRGPENALTY(runVersions,experiments,steps,scenSet,y)                     'Penalty with cost of penaltyViolateRenNrg - used to make renewable energy constraint feasible, GWh'
  s_PEAK_NZ_PENALTY(runVersions,experiments,steps,scenSet,y,scen)              'Penalty with cost of penaltyViolatePeakLoad - used to make NZ security constraint feasible, MW'
  s_PEAK_NI_PENALTY(runVersions,experiments,steps,scenSet,y,scen)              'Penalty with cost of penaltyViolatePeakLoad - used to make NI security constraint feasible, MW'
  s_NOWINDPEAK_NI_PENALTY(runVersions,experiments,steps,scenSet,y,scen)        'Penalty with cost of penaltyViolatePeakLoad - used to make NI no wind constraint feasible, MW'
  s_ANNMWSLACK(runVersions,experiments,steps,scenSet,y)                        'Slack with arbitrarily high cost - used to make annual MW built constraint feasible, MW'
  s_RENCAPSLACK(runVersions,experiments,steps,scenSet,y)                       'Slack with arbitrarily high cost - used to make renewable capacity constraint feasible, MW'
  s_HYDROSLACK(runVersions,experiments,steps,scenSet,y)                        'Slack with arbitrarily high cost - used to make limit_hydro constraint feasible, GWh'
  s_MINUTILSLACK(runVersions,experiments,steps,scenSet,y)                      'Slack with arbitrarily high cost - used to make minutil constraint feasible, GWh'
  s_FUELSLACK(runVersions,experiments,steps,scenSet,y)                         'Slack with arbitrarily high cost - used to make limit_fueluse constraint feasible, PJ'
  s_bal_supdem(runVersions,experiments,steps,scenSet,r,y,t,lb,scen)            'Balance supply and demand in each region, year, time period and load block'
  s_peak_nz(runVersions,experiments,steps,scenSet,y,scen)                      'Ensure enough capacity to meet peak demand and the winter capacity margin in NZ'
  s_peak_ni(runVersions,experiments,steps,scenSet,y,scen)                      'Ensure enough capacity to meet peak demand in NI subject to contingencies'
  s_noWindPeak_ni(runVersions,experiments,steps,scenSet,y,scen)                'Ensure enough capacity to meet peak demand in NI  subject to contingencies when wind is low'
  ;

$gdxin "%OutPath%\%runName%\GDX\allRV_ReportOutput.gdx"
$loaddc s_TOTALCOST s_TX s_REFURBCOST s_BUILD s_CAPACITY s_TXCAPCHARGES s_GEN s_VOLLGEN s_RESV s_RESVVIOL s_RESVCOMPONENTS
$loaddc s_RENNRGPENALTY s_PEAK_NZ_PENALTY s_PEAK_NI_PENALTY s_NOWINDPEAK_NI_PENALTY
$loaddc s_ANNMWSLACK s_RENCAPSLACK s_HYDROSLACK s_MINUTILSLACK s_FUELSLACK
$loaddc s_bal_supdem s_peak_nz s_peak_ni s_noWindPeak_ni

* Declare and load sets and parameters from the merged 'all_SelectedInputData' GDX file.
Sets
  possibleToBuild(runVersions,g)                       'Generating plant that may possibly be built in any valid build year'
  possibleToRefurbish(runVersions,g)                   'Generating plant that may possibly be refurbished in any valid modelled year'
  validYrOperate(runVersions,g,y)                      'Valid years in which an existing, committed or new plant can generate. Use to fix GEN to zero in invalid years' ;

Parameters
  i_fuelQuantities(runVersions,f,y)                    'Quantitative limit on availability of various fuels by year, PJ'
  i_namePlate(runVersions,g)                           'Nameplate capacity of generating plant, MW'
  i_heatrate(runVersions,g)                            'Heat rate of generating plant, GJ/GWh (default = 3600)'
  totalFuelCost(runVersions,g,y,scen)                  'Total fuel cost - price plus fuel production and delivery charges all times heatrate - by plant, year and scenario, $/MWh'
  CO2taxByPlant(runVersions,g,y,scen)                  'CO2 tax by plant, year and scenario, $/MWh'
  SRMC(runVersions,g,y,scen)                           'Short run marginal cost of each generation project by year and scenario, $/MWh'
  i_fixedOM(runVersions,g)                             'Fixed O&M costs by plant, $/kW/year'
  i_VOLLcost(runVersions,s)                            'Value of lost load by VOLL plant (1 VOLL plant/region), $/MWh'
  i_HVDCshr(runVersions,o)                             'Share of HVDC charge to be incurred by plant owner'
  i_HVDClevy(runVersions,y)                            'HVDC charge levied on new South Island plant by year, $/kW'
  i_plantReservesCost(runVersions,g,rc)                'Plant-specific cost per reserve class, $/MWh'
  hoursPerBlock(runVersions,t,lb)                      'Hours per load block by time period'
  NrgDemand(runVersions,r,y,t,lb,scen)                 'Load (or energy demand) by region, year, time period and load block, GWh (used to create ldcMW)'
  PVfacG(runVersions,y,t)                              "Generation investor's present value factor by period"
  PVfacT(runVersions,y,t)                              "Transmission investor's present value factor by period"
  capCharge(runVersions,g,y)                           'Annualised or levelised capital charge for new generation plant, $/MW/yr'
  refurbCapCharge(runVersions,g,y)                     'Annualised or levelised capital charge for refurbishing existing generation plant, $/MW/yr'
  MWtoBuild(runVersions,k,aggR)                        'MW available for installation by technology, island and NZ'
  locFac_Recip(runVersions,e)                          'Reciprocal of zonally-based location factors'
  penaltyViolateReserves(runVersions,ild,rc)           'Penalty for failing to meet certain reserve classes, $/MW'
  pNFresvCost(runVersions,r,rr,stp)                    'Constant cost of each non-free piece (or step) of function, $/MWh' ;


$gdxin "%OutPath%\%runName%\Input data checks\allRV_SelectedInputData.gdx"
$loaddc possibleToBuild possibleToRefurbish validYrOperate
$loaddc i_fuelQuantities i_namePlate i_heatrate totalFuelCost CO2taxByPlant SRMC i_fixedOM i_VOLLcost i_HVDCshr i_HVDClevy i_plantReservesCost
$loaddc hoursPerBlock NrgDemand PVfacG PVfacT capCharge refurbCapCharge MWtoBuild locFac_recip penaltyViolateReserves pNFresvCost



*===============================================================================================
* 2. Perform the calculations to be reported.

Sets
  sc(scen)                                    '(Dynamically) selected elements of scenarios'
  rv(runVersions)                             'runVersions loaded into GEMreports'
  reportDomain(experiments,steps,scenSet)     'The experiment-steps-scenarioSets tuples to be reported on'
  objc                                        'Objective function components'
                                             / obj_Check       'Check that sum of all components including TOTALCOST less TOTALCOST equals TOTALCOST'
                                               obj_total       'Objective function value'
                                               obj_gencapex    'Discounted levelised generation plant capital costs'
                                               obj_refurb      'Discounted levelised refurbishment capital costs'
                                               obj_txcapex     'Discounted levelised transmission capital costs'
                                               obj_fixOM       'After tax discounted fixed costs at generation plant'
                                               obj_varOM       'After tax discounted variable costs at generation plant'
                                               obj_hvdc        'After tax discounted HVDC charges'
                                               VOLLcost        'After tax discounted value of lost load'
                                               obj_rescosts    'After tax discounted reserve costs at generation plant'
                                               obj_resvviol    'Penalty cost of failing to meet reserves'
                                               obj_nfrcosts    'After tax discounted cost of non-free reserve cover for HVDC'
                                               obj_Penalties   'Value of all penalties'
                                               obj_Slacks      'Value of all slacks' / ;

Parameters
  cntr                                        'A counter'
  unDiscFactor(runVersions,y,t)               "Factor to adjust or 'un-discount' and 'un-tax' shadow prices and values - by period and year"
  unDiscFactorYr(runVersions,y)               "Factor to adjust or 'un-discount' and 'un-tax' shadow prices and values - by year (use last period of year)"
  objComponents(*,*,*,*,objc)                 'Components of objective function value'
  scenarioWeight(scen)                        'Individual scenario weights'
  loadByRegionAndYear(*,*,*,*,r,y)            'Load by region and year, GWh'
  builtByTechRegion(*,*,*,*,k,r)              'MW built by technology and region/island'
  builtByTech(*,*,*,*,k)                      'MW built by technology'
  builtByRegion(*,*,*,*,r)                    'MW built by region/island'
  capacityByTechRegionYear(*,*,*,*,k,r,y)     'Capacity by technology and region/island and year, MW'
  genByTechRegionYear(*,*,*,*,k,r,y)          'Generation by technology and region/island and year, GWh'
  txByRegionYear(*,*,*,*,r,rr,y)              'Interregional transmission by year, GWh'
  energyPrice(*,*,*,*,r,y)                    'Time-weighted energy price by region and year, $/MWh (from marginal price off of energy balance constraint)'
  peakNZPrice(*,*,*,*,y)                      'Shadow price off peak NZ constraint, $/kW'
  peakNIPrice(*,*,*,*,y)                      'Shadow price off peak NI constraint, $/kW'
  peaknoWindNIPrice(*,*,*,*,y)                'Shadow price off peak no wind NI constraint, $/kW'
  ;

reportDomain(%reportDomain%) = yes ;
rv(runVersions)$sum(reportDomain, s_TOTALCOST(runVersions,reportDomain)) = yes ;

unDiscFactor(rv,y,t) = 1 / ( (1 - taxRate) * PVfacG(rv,y,t) ) ;
unDiscFactorYr(rv,y) = sum(t$( ord(t) = card(t) ), unDiscFactor(rv,y,t)) ;

loop((rv,reportDomain(experiments,steps,scenSet)),

* Initialise the desired scenarios for this solve
  sc(scen) = no ;
  sc(scen)$mapScenarios(scenSet,scen) = yes ;

* Select the appropriate scenario weight.
  scenarioWeight(sc) = 0 ;
  scenarioWeight(sc) = weightScenariosBySet(scenSet,sc) ;

  objComponents(rv,reportDomain,'obj_total')     = s_TOTALCOST(rv,reportDomain) ;
  objComponents(rv,reportDomain,'obj_gencapex')  = 1e-6 * sum((y,firstPeriod(t),possibleToBuild(rv,g)), PVfacG(rv,y,t) * capCharge(rv,g,y) * s_CAPACITY(rv,reportDomain,g,y) ) ;
  objComponents(rv,reportDomain,'obj_refurb')    = 1e-6 * sum((y,firstPeriod(t),possibleToRefurbish(rv,g))$refurbCapCharge(rv,g,y), PVfacG(rv,y,t) * s_REFURBCOST(rv,reportDomain,g,y) ) ;
  objComponents(rv,reportDomain,'obj_txcapex')   = sum((paths,y,firstPeriod(t)), PVfacT(rv,y,t) * s_TXCAPCHARGES(rv,reportDomain,paths,y) ) ;
  objComponents(rv,reportDomain,'obj_fixOM')     = 1e-3 * (1 - taxRate) * sum((g,y,t), PVfacG(rv,y,t) * ( 1/card(t) ) * i_fixedOM(rv,g) * s_CAPACITY(rv,reportDomain,g,y) ) ;
  objComponents(rv,reportDomain,'obj_varOM')     = 1e-3 * (1 - taxRate) * sum((validYrOperate(rv,g,y),t,lb,sc), scenarioWeight(sc) * PVfacG(rv,y,t) * s_GEN(rv,reportDomain,g,y,t,lb,sc) * srmc(rv,g,y,sc) * sum(mapg_e(g,e), locFac_Recip(rv,e)) ) ;
  objComponents(rv,reportDomain,'obj_hvdc')      = 1e-3 * (1 - taxRate) * sum((y,t), PVfacG(rv,y,t) * ( 1/card(t) ) * (
                                                   sum((g,k,o)$((not demandGen(k)) * sigen(g) * possibleToBuild(rv,g) * mapg_k(g,k) * mapg_o(g,o)), i_HVDCshr(rv,o) * i_HVDClevy(rv,y) * s_CAPACITY(rv,reportDomain,g,y)) ) ) ;
  objComponents(rv,reportDomain,'VOLLcost')      = 1e-3 * (1 - taxRate) * sum((s,y,t,lb,sc), scenarioWeight(sc) * PVfacG(rv,y,t) * s_VOLLGEN(rv,reportDomain,s,y,t,lb,sc) * i_VOLLcost(rv,s) ) ;
  objComponents(rv,reportDomain,'obj_rescosts')  = 1e-6 * (1 - taxRate) * sum((g,rc,y,t,lb,sc), PVfacG(rv,y,t) * scenarioWeight(sc) * s_RESV(rv,reportDomain,g,rc,y,t,lb,sc) * i_plantReservesCost(rv,g,rc) ) ;

  objComponents(rv,reportDomain,'obj_resvviol')  = 1e-6 * sum((rc,ild,y,t,lb,sc), scenarioWeight(sc) * s_RESVVIOL(rv,reportDomain,rc,ild,y,t,lb,sc) * penaltyViolateReserves(rv,ild,rc) ) ;
  objComponents(rv,reportDomain,'obj_nfrcosts')  = 1e-6 * (1 - taxRate) * sum((y,t,lb), PVfacG(rv,y,t) * (
                                                   sum((paths,stp,sc)$( nwd(paths) or swd(paths) ), hoursPerBlock(rv,t,lb) * scenarioWeight(sc) * s_RESVCOMPONENTS(rv,reportDomain,paths,y,t,lb,sc,stp) * pNFresvcost(rv,paths,stp) ) ) ) ;
  objComponents(rv,reportDomain,'obj_Penalties') = sum((y,sc), scenarioWeight(sc) * (
                                                     1e-3 * penaltyViolateRenNrg * s_RENNRGPENALTY(rv,reportDomain,y) +
                                                     1e-6 * penaltyViolatePeakLoad * ( s_PEAK_NZ_PENALTY(rv,reportDomain,y,sc) + s_PEAK_NI_PENALTY(rv,reportDomain,y,sc) + s_NOWINDPEAK_NI_PENALTY(rv,reportDomain,y,sc) ) )
                                                   ) ;
  objComponents(rv,reportDomain,'obj_Slacks')    = slackCost * sum(y, s_ANNMWSLACK(rv,reportDomain,y) + s_RENCAPSLACK(rv,reportDomain,y) + s_HYDROSLACK(rv,reportDomain,y) + s_MINUTILSLACK(rv,reportDomain,y) + s_FUELSLACK(rv,reportDomain,y) ) ;

  builtByTechRegion(rv,reportDomain,k,r) = sum((g,y)$( mapg_k(g,k) * mapg_r(g,r) ), s_BUILD(rv,reportDomain,g,y)) ;

  capacityByTechRegionYear(rv,reportDomain,k,r,y)  = sum(g$( mapg_k(g,k) * mapg_r(g,r) ), s_CAPACITY(rv,reportDomain,g,y)) ;

  genByTechRegionYear(rv,reportDomain,k,r,y) = sum((g,t,lb,sc)$( mapg_k(g,k) * mapg_r(g,r) ), scenarioWeight(sc) * s_GEN(rv,reportDomain,g,y,t,lb,sc)) ;

  txByRegionYear(rv,reportDomain,paths,y) = sum((t,lb,sc), 1e-3 * scenarioWeight(sc) * hoursPerBlock(rv,t,lb) * s_TX(rv,reportDomain,paths,y,t,lb,sc)) ;

  energyPrice(rv,reportDomain,r,y) = 1e3 * sum((t,lb,sc), unDiscFactor(rv,y,t) * hoursPerBlock(rv,t,lb) * s_bal_supdem(rv,reportDomain,r,y,t,lb,sc)) / sum((t,lb), hoursPerBlock(rv,t,lb)) ;

  peakNZPrice(rv,reportDomain,y) = 1e3 * unDiscFactorYr(rv,y) * sum(sc, s_peak_nz(rv,reportDomain,y,sc) ) ;

  peakNIPrice(rv,reportDomain,y) = 1e3 * unDiscFactorYr(rv,y) * sum(sc, s_peak_ni(rv,reportDomain,y,sc) ) ;

  peaknoWindNIPrice(rv,reportDomain,y) = 1e3 * unDiscFactorYr(rv,y) * sum(sc, s_noWindPeak_ni(rv,reportDomain,y,sc) ) ;

) ;

objComponents(rv,reportDomain,'obj_Check') = sum(objc, objComponents(rv,reportDomain,objc)) - objComponents(rv,reportDomain,'obj_total') ;

loadByRegionAndYear(rv,reportDomain,r,y) = sum((t,lb,sc), scenarioWeight(sc) * NrgDemand(rv,r,y,t,lb,sc)) ;

Display unDiscFactor, unDiscFactorYr, rv, objComponents, builtByTechRegion ;



*===============================================================================================
* 3. Write out the external files.

* Write summary results to a csv file.
put summaryResults 'Objective function value components, $m' / '' ;
loop(rv, put rv.tl ) ;
loop(objc,
  put / objc.tl ;
  loop(rv, put sum(reportDomain, objComponents(rv,reportDomain,objc)) ) ;
  put objc.te(objc) ;
) ;

put //// 'MW built by technology and region (MW built as percent of MW able to be built shown in 3 columns to the right) ' ;
loop(rv,
  put / rv.tl ; loop(r$( card(isIldEqReg) <> 2 ), put r.tl ) loop(aggR, put aggR.tl ) put '' loop(aggR, put aggR.tl ) ;
  loop(k, put / k.tl
    loop(r$( card(isIldEqReg) <> 2 ), put sum(reportDomain, builtByTechRegion(rv,reportDomain,k,r)) ) ;
    loop(aggR, put sum((reportDomain,r)$mapAggR_r(aggR,r), builtByTechRegion(rv,reportDomain,k,r)) ) ;
    put '' ;
    loop(aggR,
    if(MWtoBuild(rv,k,aggR) = 0, put '' else
      put (100 * sum((reportDomain,r)$mapAggR_r(aggR,r), builtByTechRegion(rv,reportDomain,k,r)) / MWtoBuild(rv,k,aggR)) ) ;
    ) ;
    put '' k.te(k) ;
  ) ;
  put / ;
) ;

put /// 'Capacity by technology and region and year, MW (existing plus built less retired)' ;
loop(rv, put / rv.tl '' ; loop(y, put y.tl ) ;
  loop((k,r),
    put / k.tl, r.tl ;
    loop(y, put sum(reportDomain, capacityByTechRegionYear(rv,reportDomain,k,r,y)) ) ;
  ) ;
  put / ;
) ;

cntr = 0 ;
put /// 'Generation by technology, region and year, GWh' ;
loop(rv, put / rv.tl '' ; loop(y, put y.tl ) ; put / ;
  if(card(isIldEqReg) <> 2,
    loop(k,
      put k.tl ;
      loop(r,
        put$(cntr = 0) r.tl ; put$(cntr > 0) '' r.tl ; cntr = cntr + 1 ;
        loop(y, put sum(reportDomain, genByTechRegionYear(rv,reportDomain,k,r,y)) ) put / ;
      ) ;
      loop(aggR,
        put '' aggR.tl ;
        loop(y, put sum((reportDomain,r)$mapAggR_r(aggR,r), genByTechRegionYear(rv,reportDomain,k,r,y)) ) put / ;
      ) ;
    cntr = 0 ;
    ) ;
    else
    loop(k,
      put k.tl ;
      loop(aggR,
        put$(cntr = 0) aggR.tl ; put$(cntr > 0) '' aggR.tl ; cntr = cntr + 1 ;
        loop(y, put sum((reportDomain,r)$mapAggR_r(aggR,r), genByTechRegionYear(rv,reportDomain,k,r,y)) ) put / ;
      ) ;
      cntr = 0 ;
    ) ;
  ) ;
) ;

put /// 'Interregional transmission by year, GWh' ;
loop(rv, put / rv.tl '' ; loop(y, put y.tl ) ;
  loop((paths(r,rr)),
    put / r.tl, rr.tl ;
    loop(y, put sum(reportDomain, txByRegionYear(rv,reportDomain,paths,y)) ) ;
  ) ;
  put / ;
) ;

put /// 'Load by region and year, GWh' ;
loop(rv, put / rv.tl ; loop(y, put y.tl ) ;
  loop(r, put / r.tl
    loop(y, put sum(reportDomain, loadByRegionAndYear(rv,reportDomain,r,y)) ) ;
  ) ;
  put / ;
) ;

put /// 'Time-weighted energy price by region and year, $/MWh' ;
loop(rv, put / rv.tl ; loop(y, put y.tl ) ;
  loop(r, put / r.tl
    loop(y, put sum(reportDomain, energyPrice(rv,reportDomain,r,y)) ) ;
  ) ;
  put / ;
) ;

put /// 'Peak constraint shadow prices, $/kW' ;
loop(rv, put / rv.tl ; loop(y, put y.tl ) ;
  put / 'PeakNZ'       loop(y, put sum(reportDomain, peakNZPrice(rv,reportDomain,y)) ) ;
  put / 'PeakNI'       loop(y, put sum(reportDomain, peakNIPrice(rv,reportDomain,y)) ) ;
  put / 'noWindPeakNI' loop(y, put sum(reportDomain, peaknoWindNIPrice(rv,reportDomain,y)) ) ;
  put / ;
) ;

$ontext
* Write Peak constraint info to a txt file.
File PeakResults / "%OutPath%\%runName%\%runName% - %scenarioName% - PeakResults.txt" / ; PeakResults.lw = 0 ; PeakResults.pw = 999 ;
put PeakResults '1. Peak NZ' / @6 'Capacity' '  RestLHS', '      RHS', '  MargVal' ;
loop(y,
  put / y.tl:<4:0, (sum((activeExpSteps,g), peakConPlant(g,y) * s2_CAPACITY(activeExpSteps,g,y))):>9:1,
    ( -i_winterCapacityMargin(y)):>9:1,
    ( sum(sc, scenarioWeight(sc) * peakLoadNZ(y,sc)) ):>9:1
    ( sum(sc, 1000 * scenarioWeight(sc) * peak_NZ.m(y,sc)) ):>9:1
) ;

put /// '2. Peak NI' / @6 'Capacity' '  RestLHS', '      RHS', '  MargVal' ;
loop(y,
  put / y.tl:<4:0, (sum((activeExpSteps,nigen(g)), peakConPlant(g,y) * s2_CAPACITY(activeExpSteps,g,y))):>9:1,
    ( i_largestGenerator(y) + i_smallestPole(y) - i_winterCapacityMargin(y) ):>9:1,
    ( sum(sc, scenarioWeight(sc) * peakLoadNI(y,sc)) ):>9:1
    ( sum(sc, 1000 * scenarioWeight(sc) * peak_NI.m(y,sc)) ):>9:1
) ;

put /// '3. Low wind peak NI' / @6 'Capacity' '  RestLHS', '      RHS', '  MargVal' ;
loop(y,
  put / y.tl:<4:0, (sum((activeExpSteps,mapg_k(g,k))$( nigen(g) and (not wind(k)) ), NWpeakConPlant(g,y) * s2_CAPACITY(activeExpSteps,g,y))):>9:1,
    ( -i_fkNI(y) + i_smallestPole(y) ):>9:1,
    ( sum(sc, scenarioWeight(sc) * peakLoadNI(y,sc)) ):>9:1
    ( sum(sc, 1000 * scenarioWeight(sc) * noWindPeak_NI.m(y,sc)) ):>9:1
) ;
$offtext


* Write a batch file to the archive folder to be used to invoke the plotting executable.
putclose plotBat '"%MatCodePath%\GEMplots.exe" "%OutPath%\%runName%\Processed files\Results to be plotted - %runName%.csv"' / ;

* Write results to be plotted to a csv file.
put plotResults "%runName%" "%FigureTitles%", card(y) ; ! card(y) needs to indicate the number of columns of data (the first 2 cols are not data.
put // 'Technologies' ;
loop(k,
  put / k.tl, k.te(k) loop(techColor(k,red,green,blue), put red.tl, green.tl, blue.tl ) ; 
) ;

put // 'Run versions' ;
loop(rv(runVersions),
  put / runVersions.tl, runVersions.te(runVersions) loop(runVersionColor(runVersions,red,green,blue), put red.tl, green.tl, blue.tl ) ; 
) ;

put // 'Time-weighted energy price by region and year, $/MWh' / '' '' loop(y, put y.tl ) ;
loop(rv, put / rv.tl ;
  loop(r,
    put / r.tl '' ;
    loop(y, put sum(reportDomain, energyPrice(rv,reportDomain,r,y)) ) ;
  ) ;
) ;

put // 'Capacity by technology and year (existing plus built less retired), MW' / '' '' loop(y, put y.tl ) ;
loop(rv, put / rv.tl ;
  loop(k$sum((reportDomain,r,y), capacityByTechRegionYear(rv,reportDomain,k,r,y)),
    put / k.tl '' ;
    loop(y, put sum((reportDomain,r), capacityByTechRegionYear(rv,reportDomain,k,r,y)) ) ;
  ) ;
  put / 'Total' '' loop(y, put sum((reportDomain,k,r), capacityByTechRegionYear(rv,reportDomain,k,r,y)) ) ;
) ;

put // 'Generation by technology and region and year, GWh' / '' '' loop(y, put y.tl ) ;
loop(rv, put / rv.tl ;
  loop(k$sum((reportDomain,r,y), genByTechRegionYear(rv,reportDomain,k,r,y)),
    put / k.tl '' ;
    loop(y, put sum((reportDomain,r), genByTechRegionYear(rv,reportDomain,k,r,y)) ) ;
  ) ;
  put / 'Total' '' loop(y, put sum((reportDomain,k,r), genByTechRegionYear(rv,reportDomain,k,r,y)) ) ;
) ;

* Write out csv files with everything
put capacityPlant 'Capacity by plant and year (net of retirements), MW' / 'runVersion' 'Experiment' 'Step' 'scenarioSet' 'Plant' 'Year' 'MW' ;
loop((rv,experiments,steps,scenSet,g,y)$s_CAPACITY(rv,experiments,steps,scenSet,g,y),
  put / rv.tl, experiments.tl, steps.tl, scenSet.tl, g.tl, y.tl, s_CAPACITY(rv,experiments,steps,scenSet,g,y) ;
) ;

put genPlant 'Generation (GWh) and utilisation (percent) by plant and year' /
  'runVersion' 'Experiment' 'Step' 'scenarioSet' 'Plant' 'Year' 'Period' 'Block' 'Scenario' 'GWh' 'Percent' ;
loop((rv,experiments,steps,scenSet,g,y,t,lb,scen)$s_GEN(rv,experiments,steps,scenSet,g,y,t,lb,scen),
  put / rv.tl, experiments.tl, steps.tl, scenSet.tl, g.tl, y.tl, t.tl, lb.tl, scen.tl, s_GEN(rv,experiments,steps,scenSet,g,y,t,lb,scen) ;
  put (100 * s_GEN(rv,experiments,steps,scenSet,g,y,t,lb,scen) / ( 1e-3 * hoursPerBlock(rv,t,lb) * i_namePlate(rv,g) )) ;
) ;

put genPlantYear 'Annual generation (GWh) and utilisation (percent) by plant' /
  'runVersion' 'Experiment' 'Step' 'scenarioSet' 'Plant' 'Year' 'Scenario' 'GWh' 'Percent' ;
loop((rv,experiments,steps,scenSet,g,y,scen)$sum((t,lb), s_GEN(rv,experiments,steps,scenSet,g,y,t,lb,scen)),
  put / rv.tl, experiments.tl, steps.tl, scenSet.tl, g.tl, y.tl, scen.tl, sum((t,lb), s_GEN(rv,experiments,steps,scenSet,g,y,t,lb,scen)) ;
  put ( 100 * sum((t,lb), s_GEN(rv,experiments,steps,scenSet,g,y,t,lb,scen)) / ( 8.76 * i_namePlate(rv,g) ) ) ;
) ;

Set ryr 'Labels for results by year' /
  FuelPJ   'Fuel burn, PJ'
  / ;

put variousAnnual 'Various results reported by year' / ''
  'runVersion' 'Experiment' 'Step' 'scenarioSet' 'Scenario' 'Fuel' loop(y, put y.tl) ;
loop((ryr,rv,experiments,steps,scenSet,scen,thermalfuel(f))$sum((mapg_f(g,f),y,t,lb), s_GEN(rv,experiments,steps,scenSet,g,y,t,lb,scen)),
  put / ryr.te(ryr), rv.tl, experiments.tl, steps.tl, scenSet.tl, scen.tl, f.tl ;
  loop(y, put sum((mapg_f(g,f),t,lb), 1e-6 * i_heatrate(rv,g) * s_GEN(rv,experiments,steps,scenSet,g,y,t,lb,scen)) ) ;
) ;

* Need to check units are correct on Fuel burn, PJ?
* Create a parameter to calculate this stuff and move it into a loop where it all gets done at once.

*CO2taxByPlant(g,y,scen) = 1e-9 * i_heatrate(g) * sum((mapg_f(g,f),mapg_k(g,k)), i_co2tax(y) * scenarioCO2TaxFactor(scen) * i_emissionFactors(f) ) ;


$stop

Stuff to do results by year - see SOO_ReDO spreadsheet in GEM root dir.

  ryr    Labels for results by year
       / 'TxUpgrades'      'Identify the years in which transmission upgrades are made'
         'NZInstMW'        'Installed capacity in NZ, MW'
         'NZFirmMW'        'Firm capacity in NZ, MW'
         'NIInstMW'        'Installed capacity in NI, MW'
         'NIFirmMW'        'Firm capacity in NI, MW'
         'RetireMW'        'Retired capacity, MW'
         'MaxPotGWh'       'Theoretical maximum annual energy production, GWh'
         'GenGWh'          'Total New Zealand output, GWh'
         'RenewGWh'        'Energy produced from renewable sources, GWh'
         'TxGWh'           'Total New Zealand interregional transmission, GWh'
         'IITxGWh'         'Total inter-island transmission, GWh'
         'TxLossGWh'       'Total New Zealand interregional transmission losses, GWh'
         'IITxLossGWh'     'Total inter-island transmission losses, GWh'
         'IntraLossGWh'    'Total intraregional transmission losses, GWh'
         'Losses$m'        'Annual value of losses (intraregional and interregional) valued at LRMC, $m'
         'DemGWh'          'Energy demand, GWh'
         'tCO2'            'CO2e emissions, tonnes'
         'fOMpre$m'        'Fixed O&M expenses (pre tax), $m'
         'fOMpost$m'       'Fixed O&M expenses (post tax), $m'
         'HVDCpre$m'       'HVDC charges (pre tax), $m'
         'HVDCpost$m'      'HVDC charges (post tax), $m'
         'vOMpre$m'        'Variable O&M expenses with LF adjustment (pre tax), $m'
         'vOMpreNoLF$m'    'Variable O&M expenses without LF adjustment (pre tax), $m'
         'vOMpost$m'       'Variable O&M expenses with LF adjustment (post tax), $m'
         'vOMpostNoLF$m'   'Variable O&M expenses without LF adjustment (post tax), $m'
         'Fuelpre$m'       'Fuel expenses with LF adjustment (pre tax), $m'
         'FuelpreNoLF$m'   'Fuel expenses without LF adjustment (pre tax), $m'
         'Fuelpost$m'      'Fuel expenses with LF adjustment (post tax), $m'
         'FuelpostNoLF$m'  'Fuel expenses without LF adjustment (post tax), $m'
         'Ctaxpre$m'       'CO2 charges with LF adjustment (pre tax), $m'
         'CtaxpreNoLF$m'   'CO2 charges without LF adjustment (pre tax), $m'
         'Ctaxpost$m'      'CO2 charges with LF adjustment (post tax), $m'
         'CtaxpostNoLF$m'  'CO2 charges without LF adjustment (post tax), $m'
         'CCSpre$m'        'CCS expenses with LF adjustment (pre tax), $m'
         'CCSpreNoLF$m'    'CCS expenses without LF adjustment (pre tax), $m'
         'CCSpost$m'       'CCS expenses with LF adjustment (post tax), $m'
         'CCSpostNoLF$m'   'CCS expenses without LF adjustment (post tax), $m'
         'CapCost$m'       'Pre tax lumpy capital cost of new generation plants, $m (real)'
         'CapexR$m'        'Generation capex charges (net of depreciation tax credit effects) by year, $m (real)'
         'CapexPV$m'       'Generation capex charges (net of depreciation tax credit effects) by year, $m (present value)'
         'TxCapCost$m'     'Pre tax lumpy capital cost of new transmission investments by year, $m (real)'
         'TxCapexR$m'      'Transmission capex charges (net of depreciation tax credit effects) by year, $m (real)'
         'TxCapexPV$m'     'Transmission capex charges (net of depreciation tax credit effects) by year, $m (present value)'       /


* c) Compute results by year, set 'ryr'.
loop((mds,rt,hd,y)$mds_rt_hd(mds,rt,hd),
  resultsyr(mds,rt,hd,y,'TxUpgrades')     = sum(tupg, s3_txprojvar(mds,rt,tupg,y)) ;
  resultsyr(mds,rt,hd,y,'NZInstMW')       = sum(g, s3_capacity(mds,rt,g,y)) ;
  resultsyr(mds,rt,hd,y,'NZFirmMW')       = sum(g, peakconm(g,y,mds) * s3_capacity(mds,rt,g,y)) ;
  resultsyr(mds,rt,hd,y,'NIInstMW')       = sum((g,ild)$( ni(ild) * mapg_ild(g,ild) ), s3_capacity(mds,rt,g,y)) ;
  resultsyr(mds,rt,hd,y,'NIFirmMW')       = sum((g,ild)$( ni(ild) * mapg_ild(g,ild) ), peakconm(g,y,mds) * s3_capacity(mds,rt,g,y)) ;
  resultsyr(mds,rt,hd,y,'RetireMW')       = sum(g, s3_retire(mds,rt,g,y) + exogretireMWm(g,y,mds)) ;
  resultsyr(mds,rt,hd,y,'MaxPotGWh')      = sum(g, pltresultsyr(mds,rt,hd,'MaxPotGWh',g,y)) ;
  resultsyr(mds,rt,hd,y,'GenGWh')         = sum(g, pltresultsyr(mds,rt,hd,'GenGWh',g,y)) ;
  resultsyr(mds,rt,hd,y,'RenewGWh')       = sum((g,k)$( mapg_k(g,k) * renew(k) ), genyr(mds,rt,g,y,hd)) ;
  resultsyr(mds,rt,hd,y,'TxGWh')          = sum((paths(r,rr),t,lb), s3_Tx(mds,rt,paths,y,t,lb,hd) * hrsperblk(t,lb) * 1e-3 ) ;
  resultsyr(mds,rt,hd,y,'IITxGWh')        = sum((paths(r,rr),t,lb)$( nwd(r,rr) or swd(r,rr) ), s3_Tx(mds,rt,paths,y,t,lb,hd) * hrsperblk(t,lb) * 1e-3 ) ;
  resultsyr(mds,rt,hd,y,'TxLossGWh')      = sum((paths(r,rr),t,lb), s3_loss(mds,rt,paths,y,t,lb,hd) * hrsperblk(t,lb) * 1e-3 ) ;
  resultsyr(mds,rt,hd,y,'IITxLossGWh')    = sum((paths(r,rr),t,lb)$( nwd(r,rr) or swd(r,rr) ), s3_loss(mds,rt,paths,y,t,lb,hd) * hrsperblk(t,lb) * 1e-3 ) ;
  resultsyr(mds,rt,hd,y,'IntraLossGWh')   = sum((ild,r,t,lb)$mapild_r(ild,r), load(y,lb,mds,r,t) * AClossFactor(ild) / ( 1 + AClossFactor(ild) ) ) ;
  resultsyr(mds,rt,hd,y,'Losses$m')       = 1.0e-3 * %LossValue% * (resultsyr(mds,rt,hd,y,'TxLossGWh') + resultsyr(mds,rt,hd,y,'IntraLossGWh')) ;
  resultsyr(mds,rt,hd,y,'Losses$m')       = 1.0e-3 * %LossValue% * (resultsyr(mds,rt,hd,y,'TxLossGWh')) ;
  resultsyr(mds,rt,hd,y,'DemGWh')         = sum((r,t,lb), ldcMWm(mds,r,t,lb,y) * hrsperblk(t,lb)) * 1e-3 ;
  resultsyr(mds,rt,hd,y,'tCO2')           = sum(g, pltresultsyr(mds,rt,hd,'tCO2',g,y)) ;
  resultsyr(mds,rt,hd,y,'fOMpre$m')       = sum(g, pltresultsyr(mds,rt,hd,'fOMpre$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'fOMpost$m')      = sum(g, pltresultsyr(mds,rt,hd,'fOMpost$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'HVDCpre$m')      = sum(g, pltresultsyr(mds,rt,hd,'HVDCpre$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'HVDCpost$m')     = sum(g, pltresultsyr(mds,rt,hd,'HVDCpost$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'vOMpre$m')       = sum(g, pltresultsyr(mds,rt,hd,'vOMpre$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'vOMpreNoLF$m')   = sum(g, pltresultsyr(mds,rt,hd,'vOMpreNoLF$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'vOMpost$m')      = sum(g, pltresultsyr(mds,rt,hd,'vOMpost$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'vOMpostNoLF$m')  = sum(g, pltresultsyr(mds,rt,hd,'vOMpostNoLF$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'Fuelpre$m')      = sum(g, pltresultsyr(mds,rt,hd,'Fuelpre$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'FuelpreNoLF$m')  = sum(g, pltresultsyr(mds,rt,hd,'FuelpreNoLF$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'Fuelpost$m')     = sum(g, pltresultsyr(mds,rt,hd,'Fuelpost$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'FuelpostNoLF$m') = sum(g, pltresultsyr(mds,rt,hd,'FuelpostNoLF$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'Ctaxpre$m')      = sum(g, pltresultsyr(mds,rt,hd,'Ctaxpre$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'CtaxpreNoLF$m')  = sum(g, pltresultsyr(mds,rt,hd,'CtaxpreNoLF$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'Ctaxpost$m')     = sum(g, pltresultsyr(mds,rt,hd,'Ctaxpost$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'CtaxpostNoLF$m') = sum(g, pltresultsyr(mds,rt,hd,'CtaxpostNoLF$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'CCSpre$m')       = sum(g, pltresultsyr(mds,rt,hd,'Ctaxpre$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'CCSpreNoLF$m')   = sum(g, pltresultsyr(mds,rt,hd,'CCSpreNoLF$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'CCSpost$m')      = sum(g, pltresultsyr(mds,rt,hd,'CCSpost$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'CCSpostNoLF$m')  = sum(g, pltresultsyr(mds,rt,hd,'CCSpostNoLF$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'CapCost$m')      = sum(g, pltresultsyr(mds,rt,hd,'CapCost$m',g,y)) ;
  resultsyr(mds,rt,hd,y,'CapexR$m')       = capchrgyr_r(mds,rt,y) ;
  resultsyr(mds,rt,hd,y,'CapexPV$m')      = sum(gend(d), capchrgyr_pv(mds,rt,y,d)) ;
  resultsyr(mds,rt,hd,y,'TxCapCost$m')    = sum(transitions(tupg,r,rr,ps,pss)$alltxps(r,rr,pss), txcapcost(r,rr,pss) * s3_txprojvar(mds,rt,tupg,y)) ;
  resultsyr(mds,rt,hd,y,'TxCapexR$m')     = txcapchrgyr_r(mds,rt,y) ;
  resultsyr(mds,rt,hd,y,'TxCapexPV$m')    = sum(txd(d), txcapchrgyr_pv(mds,rt,y,d)) ;
) ;


* Write out results by year, set 'ryr'.
* - Row headers - Attribute, run type, and hydro domain.
* - Column header is years.
* - One table of results per file, one file per MDS.
loop(mds$mds_sim(mds),

  putclose bat 'copy temp.dat "' "%OutPath%\%OutPrefix%\Processed files\", "%OutPrefix%", ' - Yearly info - All inflows - ' ,mds.tl, '.%suffix%"' / ;

  put temp 'Series', 'RT', 'hd' ; loop(y, put y.tl ) ;
  loop((ryr,rt,hd)$( sum(y, resultsyr(mds,rt,hd,y,ryr)) ),
    put / put ryr.te(ryr), rt.tl, hd.tl ;
    loop(y, put resultsyr(mds,rt,hd,y,ryr)) ;
  ) ;
  putclose ;
  
  execute 'temp.bat';

) ;














* d) Sets and parameters declared for the first time (local to GEMreports).
Sets
  a                                             'Activity related to generation investment'
                                                  /  blt   'Potential and actual built capacity by technology (gross of retirements)'
                                                    rfb   'Potential and actual refurbished capacity by technology'
                                                    rtd   'Potential and actual retired capacity by technology'   /
  buildSoln(mt)                                 'Determine which run type element to use for reporting results related to building generation or transmission'
  activeMTOC(sc,mt,scenarios)                    'Determine the sc-mt-scenario index used for each solve'
  activeCapacity(sc,g,y)                        'Identify all plant that are active in any given year, i.e. existing or built but never retired'
* Components of objective function
  objc                                          'Objective function components'
                                                  / obj_total       'Objective function value'
                                                    obj_gencapex    'Discounted levelised generation plant capital costs'
                                                    obj_refurb      'Discounted levelised refurbishment capital costs'
                                                    obj_txcapex     'Discounted levelised transmission capital costs'
                                                    obj_fixOM       'After tax discounted fixed costs at generation plant'
                                                    obj_hvdc        'After tax discounted HVDC charges'
                                                    obj_varOM       'After tax discounted variable costs at generation plant'
                                                    VOLLcost        'After tax discounted value of lost load'
                                                    obj_rescosts    'After tax discounted reserve costs at generation plant'
                                                    obj_nfrcosts    'After tax discounted cost of non-free reserve cover for HVDC'
                                                    obj_renNrg      'Penalty cost of failing to meet renewables target'
                                                    obj_resvviol    'Penalty cost of failing to meet reserves'
                                                    slk_rstrctMW    'Slack on restriction on annual MW built'
                                                    slk_nzsec       'Slack on NZ security constraint'
                                                    slk_ni1sec      'Slack on NI1 security constraint'
                                                    slk_ni2sec      'Slack on NI2 security constraint'
                                                    slk_nzNoWnd     'Slack on NZ no wind security constraint'
                                                    slk_niNoWnd     'Slack on NI no wind security constraint'
                                                    slk_renCap      'Slack on renewable capacity constraint'
                                                    slk_limHyd      'Slack on limit hydro output constraint'
                                                    slk_minutil     'Slack on minimum utilisation constraint'
                                                    slk_limFuel     'Slack on limit fuel use constraint'  /
  pen(objc)                                     'Penalty components of objective function'
                                                  / obj_renNrg, obj_resvviol /
  slk(objc)                                     'Slack components of objective function'
                                                  / slk_rstrctMW, slk_nzsec, slk_ni1sec, slk_ni2sec, slk_nzNoWnd, slk_niNoWnd, slk_renCap, slk_limHyd, slk_minutil, slk_limFuel /
  ;

Parameters
* Parameters declared for the first time (local to GEMreports).
  counter                                       'A recyclable counter'
  problems                                      'A flag indicating problems with some solutions - other than the presence of slacks or penalties'
  warnings                                      'A flag indicating warnings - warnings are much less serious than problems (problems ought not be ignored)'
  objComponentsYr(sc,mt,y,*)                    'Components of objective function value by year (tmg, reo and average over all hydrology for the dispatch solves)'
  objComponents(sc,mt,objc)                     'Components of objective function value (tmg, reo and average over all hydrology for the dispatch solves)'
  numGenPlant(sc)                               'Number of generating plant in data file'
  numVOLLplant(sc)                              'Number of shortage generating plant in data file'
  numExist(sc)                                  'Number of generating plant that are presently operating'
  numCommit(sc)                                 'Number of generating plant that are assumed to be committed'
  numNew(sc)                                    'Number of potential generating plant that are neither existing nor committed'
  numNeverBuild(sc)                             'Number of generating plant that are determined a priori by user never to be built'
  numZeroMWplt(sc)                              'Number of generating plant that are specified in input data to have a nameplate capacity of zero MW'
  numSchedHydroPlant(sc)                        'Number of schedulable hydro generation plant'
* Capacity and dispatch
  potentialCap(sc,k,a)                          'Potential capacity able to be built/refurbished/retired by technology, MW'
  actualCap(sc,mt,k,a)                          'Actual capacity built/refurbished/retired by technology, MW'
  actualCapPC(sc,mt,k,a)                        'Actual capacity built/refurbished/retired as a percentage of potential by technology'
  partialMWbuilt(sc,g)                          'The MW actually built in the case of plant not fully constructed'
  numYrsToBuildPlant(sc,g,y)                    'Identify the number of years taken to build a generating plant (-1 indicates plant is retired)'
  buildOrRetireMW(sc,g,y)                       'Collect up both build (positive) and retirement (negative), MW'
  buildYr(sc,g)                                 'Year in which new generating plant is built, or first built if built over multiple years'
  retireYr(sc,g)                                'Year in which generating plant is retired'
  buildMW(sc,g)                                 'MW built at each generating plant able to be built'
  retireMW(sc,g)                                'MW retired at each generating plant able to be retired'
  finalMW(sc,g)                                 'Existing plus built less retired MW by plant'
  totalExistMW(sc)                              'Total existing generating capacity, MW'
  totalExistDSM(sc)                             'Total existing DSM and IL capacity, MW'
  totalBuiltMW(sc)                              'Total new generating capacity installed, MW'
  totalBuiltDSM(sc)                             'Total new DSM and IL capacity installed, MW'
  totalRetiredMW(sc)                            'Total retired capacity, MW'
  genYr(sc,mt,scenarios,g,y)                     'Generation by plant and year, GWh'
  genGWh(sc,mt,scenarios)                        'Generation - includes DSM, IL and shortage (deficit) generation, GWh'
  genTWh(sc,mt,scenarios)                        'Generation - includes DSM, IL and shortage (deficit) generation, TWh'
  genDSM(sc,mt,scenarios)                        'DSM and IL dispatched, GWh'
  genPeaker(sc,mt,scenarios)                     'Generation by peakers, GWh'
  deficitGen(sc,mt,scenarios,y,t,lb)             'Aggregate deficit generation (i.e. sum over all shortage generators), GWh'
  xsDeficitGen(sc,mt,scenarios,y,t,lb)           'Excessive deficit generation in any load block, period or year (excessive means it exceeds 3% of total generation), GWh'
* Transmission
  actualTxCap(sc,mt,r,rr,y)                     'Actual transmission capacity for each path in each modelled year (may depend on endogenous decisions)'
  priorTxCap(sc,r,rr,ps)                        'Transmission capacity prior to a state change for all states (silent, though, on when state changes), MW'
  postTxCap(sc,r,rr,ps)                         'Transmission capacity after a state change for all states (silent, though, on when state changes), MW'
  numYrsToBuildTx(sc,tupg,y)                    'Identify the number of years taken to build a particular upgrade of a transmission investment'
  interTxLossYrGWh(sc,mt,scenarios,y)            'Interregional transmission losses by year, GWh'
  interTxLossGWh(sc,mt,scenarios)                'Total interregional transmission losses, GWh'
  intraTxLossYrGWh(sc,y)                        'Intraregional transmission losses by year, GWh'
  intraTxLossGWh(sc)                            'Total intraregional transmission losses, GWh'
  ;



*===============================================================================================
* 3. Declare output files and set their attributes.

* .pc = 5 ==> comma-delimited text file, aka Excel .csv
* .pc = 6 ==> tab-delimited text file, .txt - good for Matlab.
$set delim  5
$set suffix csv
$if %delim%==6 $set suffix txt

Files
* Human-readable or formatted output files.
  ss        Solve summary report                      / "%OutPath%\%runName%\%runName% - A solve summary report.txt" /
  bld       A build and retirement schedule           / "%OutPath%\%runName%\%runName% - Generation plant build and retirement schedule.%suffix%" /
  invest    Investment schedules by year              / "%OutPath%\%runName%\%runName% - Gen and Tx investment schedules by year.txt" /
  sooBld    SOO build and retirement schedule         / "%OutPath%\%runName%\%runName% - SOO plant build and retirement schedule.%suffix%" /
* Machine-readable output files - for use by other applications.
  colors   'Colours for scenarios, techs, fuels etc'  / "%OutPath%\%runName%\Processed files\%runName% - Colours.txt" /
  pltgeo    Generation with geo                       / "%OutPath%\%runName%\Processed files\%runName% - Generation build and retirements by year with georeferencing.txt" /
  txgeo     Transmission upgrades with geo            / "%OutPath%\%runName%\Processed files\%runName% - Transmission grid and upgrades by year with georeferencing.txt" /
  ;

ss.ap = 0 ;          ss.lw = 0 ;
bld.pc = %delim% ;
invest.pw = 1000 ;   invest.lw = 0 ;
sooBld.pc = %delim% ;

colors.lw = 0 ;      colors.pc = 6 ;
pltgeo.pw = 1000 ;   pltgeo.lw = 0 ;         pltgeo.pc = 6 ;
txgeo.pw = 1000 ;    txgeo.lw = 0 ;          txgeo.pc = 6 ;


* Write out the colours for scenarios, technologies and fuels (NB: as they apply to the first scenario).
put colors '// Scenarios' ;
loop(scenarioColor(sc,red,green,blue), put / sc.tl, sc.te(sc), red.tl, green.tl, blue.tl ) ;
put // '// Technologies' ;
loop(k, put / k.tl, k.te(k) loop(techColor(sc,k,red,green,blue)$(ord(sc) = 1), put red.tl, green.tl, blue.tl ) ) ;
put // '// Fuels' ;
loop(f, put / f.tl, f.te(f) loop(fuelColor(sc,f,red,green,blue)$(ord(sc) = 1), put red.tl, green.tl, blue.tl ) ) ;
put // '// Fuel groups' ;
loop(fg, put / fg.tl, fg.te(fg) loop(fuelGrpColor(sc,fg,red,green,blue)$(ord(sc) = 1), put red.tl, green.tl, blue.tl ) ) ;



*===============================================================================================
* 4. Perform the various calculations/assignments necessary to generate reports.

activeMTOC(sc,mt,scenarios) $sum(hY, activeOC(sc,mt,hY,scenarios) ) = yes ;

* a) Objective function components - value by year and total value
* Objective function components - value by year (Note that for run type 'dis', it's the average that gets computed).
objComponentsYr(activeMT(sc,mt),y,'PVfacG_t1')    = sum(firstPeriod(sc,t), PVfacG(sc,y,t)) ;
objComponentsYr(activeMT(sc,mt),y,'PVfacT_t1')    = sum(firstPeriod(sc,t), PVfacT(sc,y,t)) ;
objComponentsYr(activeMT(sc,mt),y,'obj_total')    = s2_TOTALCOST(sc,mt) ;
objComponentsYr(activeMT(sc,mt),y,'obj_gencapex') = 1e-6 * sum(possibleToBuild(sc,g), capCharge(sc,g,y) * s2_CAPACITY(sc,mt,g,y) ) ;
objComponentsYr(activeMT(sc,mt),y,'obj_refurb')   = 1e-6 * sum(possibleToRefurbish(sc,g), s2_REFURBCOST(sc,mt,g,y) ) ;
objComponentsYr(activeMT(sc,mt),y,'obj_txcapex')  = sum(paths(sc,r,rr), s2_TXCAPCHARGES(sc,mt,r,rr,y) ) ;
objComponentsYr(activeMT(sc,mt),y,'obj_fixOM')    = 1e-6 / card(t) * (1 - taxRate) * sum((g,t), PVfacG(sc,y,t) * i_fixedOM(sc,g) * s2_CAPACITY(sc,mt,g,y)) ;
objComponentsYr(activeMT(sc,mt),y,'obj_hvdc')     = 1e-6 / card(t) * (1 - taxRate) *
                                                      sum((g,k,o,t)$( (not demandGen(sc,k)) * sigen(sc,g) * possibleToBuild(sc,g) * mapg_k(sc,g,k) * mapg_o(sc,g,o) ),
                                                        PVfacG(sc,y,t) * i_HVDCshr(sc,o) * i_HVDClevy(sc,y) * s2_CAPACITY(sc,mt,g,y) ) ;
objComponentsYr(activeMT(sc,mt),y,'obj_varOM')    = 1e-6 * (1 - taxRate) * sum((t,scenarios) , PVfacG(sc,y,t) * 1e3 * i_scenarioWeight(sc,scenarios)  *
                                                      sum((g,lb), s2_GEN(sc,mt,g,y,t,lb,scenarios)  * SRMC(sc,g,y) * sum(mapg_e(sc,g,e), locFac_Recip(sc,e)) ) ) ;
objComponentsYr(activeMT(sc,mt),y,'VoLLcost')     = 1e-6 * (1 - taxRate) * sum((t,scenarios) , PVfacG(sc,y,t) * 1e3 * i_scenarioWeight(sc,scenarios)  *
                                                      sum((s,lb), s2_VOLLGEN(sc,mt,s,y,t,lb,scenarios)  * i_VOLLcost(sc,s) ) ) ;
objComponentsYr(activeMT(sc,mt),y,'obj_rescosts') = 1e-6 * (1 - taxRate) * sum((g,rc,t,lb,scenarios) , PVfacG(sc,y,t) * i_scenarioWeight(sc,scenarios)  * s2_RESV(sc,mt,g,rc,y,t,lb,scenarios)  * i_plantReservesCost(sc,g,rc) ) ;
objComponentsYr(activeMT(sc,mt),y,'obj_nfrcosts') = 1e-6 * (1 - taxRate) * sum((r,rr,t,lb,scenarios, stp)$( nwd(sc,r,rr) or swd(sc,r,rr) ),
                                                      PVfacG(sc,y,t) * i_scenarioWeight(sc,scenarios)  * (hoursPerBlock(sc,t,lb) * s2_RESVCOMPONENTS(sc,mt,r,rr,y,t,lb,scenarios, stp)) * pNFresvCost(sc,r,rr,stp) ) ;
objComponentsYr(activeMT(sc,mt),y,'obj_renNrg')   = penaltyViolateRenNrg * s2_RENNRGPENALTY(sc,mt,y) ;
objComponentsYr(activeMT(sc,mt),y,'obj_resvviol') = 1e-6 * sum((rc,ild,t,lb,scenarios) , i_scenarioWeight(sc,scenarios)  * reserveViolationPenalty(sc,ild,rc) * s2_RESVVIOL(sc,mt,rc,ild,y,t,lb,scenarios)  ) ;
objComponentsYr(activeMT(sc,mt),y,'slk_rstrctMW') = 9999 * s2_ANNMWSLACK(sc,mt,y) ;
objComponentsYr(activeMT(sc,mt),y,'slk_rencap')   = 9998 * s2_RENCAPSLACK(sc,mt,y) ;
objComponentsYr(activeMT(sc,mt),y,'slk_limhyd')   = 9997 * s2_HYDROSLACK(sc,mt,y) ;
objComponentsYr(activeMT(sc,mt),y,'slk_minutil')  = 9996 * s2_MINUTILSLACK(sc,mt,y) ;
objComponentsYr(activeMT(sc,mt),y,'slk_limfuel')  = 9995 * s2_FUELSLACK(sc,mt,y) ;

* +++ The 's2' penalty params need the domain to be defined on scenarios or oc, i.e. between the mt and the y
* +++ Also, penaltyLostPeak has yet to be passed along to the GDX that GEMreports grabs it data from.
* +++ ditto the bunch of lines about 30 lines down from here. 
*objComponentsYr(activeMT(sc,mt),y,'penalty_nzsec')    = penaltyLostPeak * s2_SEC_NZ_PENALTY(sc,mt,y) ;
*objComponentsYr(activeMT(sc,mt),y,'penalty_ni1sec')   = penaltyLostPeak * s2_SEC_NI1_PENALTY(sc,mt,y) ;
*objComponentsYr(activeMT(sc,mt),y,'penalty_ni2sec')   = penaltyLostPeak * s2_SEC_NI2_PENALTY(sc,mt,y) ;
*objComponentsYr(activeMT(sc,mt),y,'penalty_nzNoWnd')  = penaltyLostPeak * s2_NOWIND_NZ_PENALTY(sc,mt,y) ;
*objComponentsYr(activeMT(sc,mt),y,'penalty_niNoWnd')  = penaltyLostPeak * s2_NOWIND_NI_PENALTY(sc,mt,y) ;

* Objective function components - total value (Note that for run type 'dis', it's the average that gets computed).
objComponents(activeMT(sc,mt),'obj_total')    = s2_TOTALCOST(sc,mt) ;
objComponents(activeMT(sc,mt),'obj_gencapex') = 1e-6 * sum((y,firstPeriod(sc,t),possibleToBuild(sc,g)), PVfacG(sc,y,t) * capCharge(sc,g,y) * s2_CAPACITY(sc,mt,g,y) ) ;
objComponents(activeMT(sc,mt),'obj_refurb')   = 1e-6 * sum((y,firstPeriod(sc,t),possibleToRefurbish(sc,g)), PVfacG(sc,y,t) * s2_REFURBCOST(sc,mt,g,y) ) ;
objComponents(activeMT(sc,mt),'obj_txcapex')  = sum((paths(sc,r,rr),y,firstPeriod(sc,t)), PVfacT(sc,y,t) * s2_TXCAPCHARGES(sc,mt,r,rr,y) ) ;
objComponents(activeMT(sc,mt),'obj_fixOM')    = 1e-6 / card(t) * (1 - taxRate) * sum((g,y,t), PVfacG(sc,y,t) * i_fixedOM(sc,g) * s2_CAPACITY(sc,mt,g,y)) ;
objComponents(activeMT(sc,mt),'obj_hvdc')     = 1e-6 / card(t) * (1 - taxRate) *
                                                  sum((g,k,o,y,t)$( (not demandGen(sc,k)) * sigen(sc,g) * possibleToBuild(sc,g) * mapg_k(sc,g,k) * mapg_o(sc,g,o) ),
                                                    PVfacG(sc,y,t) * i_HVDCshr(sc,o) * i_HVDClevy(sc,y) * s2_CAPACITY(sc,mt,g,y) ) ;
objComponents(activeMT(sc,mt),'obj_varOM')    = 1e-6 * (1 - taxRate) * sum((y,t,scenarios) , PVfacG(sc,y,t) * 1e3 * i_scenarioWeight(sc,scenarios)  *
                                                  sum((g,lb), s2_GEN(sc,mt,g,y,t,lb,scenarios)  * SRMC(sc,g,y) * sum(mapg_e(sc,g,e), locFac_Recip(sc,e)) ) ) ;
objComponents(activeMT(sc,mt),'VoLLcost')     = 1e-6 * (1 - taxRate) * sum((y,t,scenarios) , PVfacG(sc,y,t) * 1e3 * i_scenarioWeight(sc,scenarios)  *
                                                  sum((s,lb), s2_VOLLGEN(sc,mt,s,y,t,lb,scenarios)  * i_VOLLcost(sc,s) ) ) ;
objComponents(activeMT(sc,mt),'obj_rescosts') = 1e-6 * (1 - taxRate) * sum((g,rc,y,t,lb,scenarios) , PVfacG(sc,y,t) * i_scenarioWeight(sc,scenarios)  * s2_RESV(sc,mt,g,rc,y,t,lb,scenarios)  * i_plantReservesCost(sc,g,rc) ) ;
objComponents(activeMT(sc,mt),'obj_nfrcosts') = 1e-6 * (1 - taxRate) * sum((r,rr,y,t,lb,scenarios, stp)$( nwd(sc,r,rr) or swd(sc,r,rr) ),
                                                  PVfacG(sc,y,t) * i_scenarioWeight(sc,scenarios)  * (hoursPerBlock(sc,t,lb) * s2_RESVCOMPONENTS(sc,mt,r,rr,y,t,lb,scenarios, stp)) * pNFresvCost(sc,r,rr,stp) ) ;
objComponents(activeMT(sc,mt),'obj_renNrg')   = sum(y, penaltyViolateRenNrg * s2_RENNRGPENALTY(sc,mt,y)) ;
objComponents(activeMT(sc,mt),'obj_resvviol') = 1e-6 * sum((rc,ild,y,t,lb,scenarios) , i_scenarioWeight(sc,scenarios)  * reserveViolationPenalty(sc,ild,rc) * s2_RESVVIOL(sc,mt,rc,ild,y,t,lb,scenarios)  ) ;
objComponents(activeMT(sc,mt),'slk_rstrctMW') = 9999 * sum(y, s2_ANNMWSLACK(sc,mt,y)) ;
objComponents(activeMT(sc,mt),'slk_rencap')   = 9998 * sum(y, s2_RENCAPSLACK(sc,mt,y)) ;
objComponents(activeMT(sc,mt),'slk_limhyd')   = 9997 * sum(y, s2_HYDROSLACK(sc,mt,y)) ;
objComponents(activeMT(sc,mt),'slk_minutil')  = 9996 * sum(y, s2_MINUTILSLACK(sc,mt,y)) ;
objComponents(activeMT(sc,mt),'slk_limfuel')  = 9995 * sum(y, s2_FUELSLACK(sc,mt,y)) ;

*objComponents(activeMT(sc,mt),'penalty_nzsec')    = penaltyLostPeak * sum(y, s2_SEC_NZ_PENALTY(sc,mt,y)) ;
*objComponents(activeMT(sc,mt),'penalty_ni1sec')   = penaltyLostPeak * sum(y, s2_SEC_NI1_PENALTY(sc,mt,y)) ;
*objComponents(activeMT(sc,mt),'penalty_ni2sec')   = penaltyLostPeak * sum(y, s2_SEC_NI2_PENALTY(sc,mt,y)) ;
*objComponents(activeMT(sc,mt),'penalty_nzNoWnd')  = penaltyLostPeak * sum(y, s2_NOWIND_NZ_PENALTY(sc,mt,y)) ;
*objComponents(activeMT(sc,mt),'penalty_niNoWnd')  = penaltyLostPeak * sum(y, s2_NOWIND_NI_PENALTY(sc,mt,y)) ;


* b) Various counts
numGenPlant(sc)  = card(g) ;
numVOLLplant(sc) = card(s) ;
numExist(sc)     = sum(exist(sc,g), 1 );
numCommit(sc)    = sum(commit(sc,g), 1 );
numNew(sc)       = sum(new(sc,g), 1 );
numNeverBuild(sc) = sum(neverBuild(sc,g), 1 );
numZeroMWplt(sc)  = sum(g$( i_nameplate(sc,g) = 0 ), 1 ) ;
numSchedHydroPlant(sc) = sum(schedHydroPlant(sc,g), 1 ) ;

* Use this to sort out plant status discrepancies
$ontext
File xxx / xxx.txt / ; xxx.lw=0; put xxx @20 'Exist ' 'Comit' '  New' '  Neva' ;
loop((g,sc),
  put / g.tl @15 sc.tl ;
  if(exist(sc,g),      put @24 '1' else put @24 '-' ) ;
  if(commit(sc,g),     put @30 '1' else put @30 '-' ) ;
  if(new(sc,g),        put @35 '1' else put @35 '-' ) ;
  if(neverBuild(sc,g), put @40 '1' else put @40 '-' ) ;
) ;
$offtext

* Initialise the set called 'buildSoln' based on choice of values for Runtype and SuppressReopt.
$if %RunType%%SuppressReopt%==00 buildSoln('reo') = yes ;
$if %RunType%%SuppressReopt%==01 buildSoln('tmg') = yes ;
$if %RunType%%SuppressReopt%==10 buildSoln('reo') = yes ;
$if %RunType%%SuppressReopt%==11 buildSoln('tmg') = yes ;
$if %RunType%==2 buildSoln('dis') = yes ;

buildYr(sc,g) = 0 ;
retireYr(sc,g) = 0 ;
retireMW(sc,g) = 0 ;

loop(activeMT(sc,mt),

* Capacity and dispatch
  potentialCap(sc,k,'blt') = sum(possibleToBuild(sc,g)$mapg_k(sc,g,k), i_nameplate(sc,g)) ;
  potentialCap(sc,k,'rfb') = sum(possibleToRefurbish(sc,g)$mapg_k(sc,g,k), i_nameplate(sc,g)) ;
  potentialCap(sc,k,'rtd') = sum(possibleToRetire(sc,g)$mapg_k(sc,g,k), i_nameplate(sc,g)) ;

* Calculations that relate only to the run type in which capacity expansion/contraction decisions are made.
  if(buildSoln(mt),

    activeCapacity(sc,g,y)$s2_CAPACITY(sc,mt,g,y) = yes ;

    actualCap(sc,mt,k,'blt') = sum(validYrBuild(sc,g,y)$mapg_k(sc,g,k), s2_BUILD(sc,mt,g,y)) ;
    actualCap(sc,mt,k,'rfb') = sum(possibleToRefurbish(sc,g)$mapg_k(sc,g,k), (1 - s2_ISRETIRED(sc,mt,g)) * i_nameplate(sc,g) ) ;
    actualCap(sc,mt,k,'rtd') = sum((possibleToRetire(sc,g),y)$mapg_k(sc,g,k), s2_RETIRE(sc,mt,g,y) + exogMWretired(sc,g,y)) ;

    actualCapPC(sc,mt,k,a)$potentialCap(sc,k,a) = 100 * actualCap(sc,mt,k,a) / potentialCap(sc,k,a) ;

    partialMWbuilt(sc,g)$( (i_nameplate(sc,g) - sum(y, s2_BUILD(sc,mt,g,y)) > 1.0e-9) ) = sum(y, s2_BUILD(sc,mt,g,y)) ;

    counter = 0 ;
    loop(g,
      loop(y$s2_BUILD(sc,mt,g,y),
        counter = counter + 1 ;
        numYrsToBuildPlant(sc,g,y) = counter ;
      ) ;
      counter = 0 ;
    ) ;
    numYrsToBuildPlant(sc,g,y)$( s2_RETIRE(sc,mt,g,y) or exogMWretired(sc,g,y) ) = -1 ;

    buildOrRetireMW(sc,g,y) = s2_BUILD(sc,mt,g,y) - s2_RETIRE(sc,mt,g,y) - exogMWretired(sc,g,y) ;

    loop(y,
      buildYr(sc,g)$(  buildYr(sc,g) = 0  and   s2_BUILD(sc,mt,g,y) ) = yearNum(sc,y) ;
      retireYr(sc,g)$( retireYr(sc,g) = 0 and ( s2_RETIRE(sc,mt,g,y) or exogMWretired(sc,g,y) ) ) = yearNum(sc,y) ;
    ) ;

    buildMW(sc,g)  = sum(y, s2_BUILD(sc,mt,g,y)) ;
    retireMW(sc,g) = sum(y, s2_RETIRE(sc,mt,g,y) + exogMWretired(sc,g,y)) ;
    finalMW(sc,g)  = i_nameplate(sc,g)$exist(sc,g) + buildMW(sc,g) - retireMW(sc,g) ;

    totalExistMW(sc)  = sum((g,f)$( exist(sc,g) * mapg_f(sc,g,f) ), i_nameplate(sc,g) ) ;
    totalExistDSM(sc) = sum((g,k)$( exist(sc,g) * mapg_k(sc,g,k) * demandGen(sc,k) ), i_nameplate(sc,g) ) ;

    totalBuiltMW(sc)  = sum(g, buildMW(sc,g)) ;
    totalBuiltDSM(sc) = sum((g,k)$( mapg_k(sc,g,k) * demandGen(sc,k) ), buildMW(sc,g)) ;

    totalRetiredMW(sc) = sum(g, retireMW(sc,g)) ;

* End of capacity expansion/contraction calculations.
  ) ;

  genYr(activeMTOC(sc,mt,scenarios) ,g,y) = sum((t,lb), s2_GEN(sc,mt,g,y,t,lb,scenarios) ) ;

  genGWh(activeMTOC(sc,mt,scenarios) ) = sum((g,y), genYr(sc,mt,scenarios, g,y)) ;
  genTWh(activeMTOC(sc,mt,scenarios) ) = 1e-3 * genGWh(sc,mt,scenarios)  ;
  genDSM(activeMTOC(sc,mt,scenarios) ) = sum((g,y,k)$( mapg_k(sc,g,k) * demandGen(sc,k) ), genYr(sc,mt,scenarios, g,y)) ;
  genPeaker(activeMTOC(sc,mt,scenarios) ) = sum((g,y,k)$( mapg_k(sc,g,k) * peaker(sc,k) ), genYr(sc,mt,scenarios, g,y)) ;

  deficitGen(activeMTOC(sc,mt,scenarios) ,y,t,lb) = sum(s, s2_VOLLGEN(sc,mt,s,y,t,lb,scenarios) ) ;
  xsDeficitGen(activeMTOC(sc,mt,scenarios) ,y,t,lb)$( deficitGen(sc,mt,scenarios, y,t,lb) > ( .03 * sum(g, s2_GEN(sc,mt,g,y,t,lb,scenarios) ) ) ) = deficitGen(sc,mt,scenarios, y,t,lb) ;

* Transmission
  actualTxCap(sc,mt,r,rr,y)$paths(sc,r,rr) = sum(ps, i_txCapacity(sc,r,rr,ps) * s2_BTX(sc,mt,r,rr,ps,y)) ; 

  loop(ps,
    priorTxCap(sc,r,rr,ps)$allowedStates(sc,r,rr,ps) = i_txCapacity(sc,r,rr,ps) ;
    postTxCap(sc,r,rr,ps+1)$allowedStates(sc,r,rr,ps+1) = i_txCapacity(sc,r,rr,ps+1) ;
  ) ;

  counter = 0 ;
  loop(tupg$buildSoln(mt),
    loop(y$s2_TXPROJVAR(sc,mt,tupg,y),
      counter = counter + 1 ;
      numYrsToBuildTx(sc,tupg,y) = counter ;
    ) ;
    counter = 0 ;
  ) ;

  interTxLossYrGWh(activeMTOC(sc,mt,scenarios) ,y) = 1e-3 * sum((r,rr,t,lb), s2_LOSS(sc,mt,r,rr,y,t,lb,scenarios)  * hoursPerBlock(sc,t,lb) ) ;
  interTxLossGWh(activeMTOC(sc,mt,scenarios) ) = sum(y, interTxLossYrGWh(sc,mt,scenarios, y)) ; 

  intraTxLossYrGWh(sc,y) = sum((ild,r,t,lb)$mapild_r(sc,ild,r), NrgDemand(sc,r,y,t,lb) * AClossFactors(sc,ild) / ( 1 + AClossFactors(sc,ild) ) ) ;
  intraTxLossGWh(sc) = sum(y, intraTxLossYrGWh(sc,y)) ;

) ;


Display
  objComponentsYr, objComponents, numGenPlant, numVOLLplant, numExist, numCommit, numNew, numNeverBuild, numZeroMWplt, numSchedHydroPlant
  potentialCap, actualCap, actualCapPC, partialMWbuilt, numYrsToBuildPlant, buildOrRetireMW, buildYr, retireYr, buildMW, retireMW, finalMW
  totalExistMW, totalExistDSM, totalBuiltMW, totalBuiltDSM, totalRetiredMW, genYr, genGWh, genTWh, genDSM, genPeaker, deficitGen, xsDeficitGen
  actualTxCap, priorTxCap, postTxCap, numYrsToBuildTx, interTxLossYrGWh, interTxLossGWh, intraTxLossYrGWh, intraTxLossGWh
  ;



*===============================================================================================
* 5. Write out the generation and transmission investment schedules in various formats.

* a) Build, refurbishment and retirement data and scenarios in .csv format suitable for importing into Excel.
put bld 'Scenario', 'Plant', 'Plant name', 'Zone', 'Region', 'Island', 'Technology', 'Fuel', 'RetireType', 'NameplateMW'
        'BuildYr', 'BuildMW', 'RefurbYr', 'RetireYr', 'RetireMW' ;
loop((sc,mt,g,e,r,ild,k,f,y)$( buildSoln(mt) * mapg_e(sc,g,e) * mapg_r(sc,g,r) * mapg_ild(sc,g,ild) * mapg_k(sc,g,k) * mapg_f(sc,g,f) * buildOrRetireMW(sc,g,y) ),
  put / sc.tl, g.tl, g.te(g), e.te(e), r.te(r), ild.tl, k.te(k), f.te(f) ;
  if(possibleToRetire(sc,g), if(exogMWretired(sc,g,y), put 'Exogenous' else put 'Endogenous' ) else put '' ) ; 
  put i_nameplate(sc,g) ;
  if(s2_BUILD(sc,mt,g,y), put yearNum(sc,y), s2_BUILD(sc,mt,g,y) else put '', '' ) ;
  if(possibleToRefurbish(sc,g) and (s2_ISRETIRED(sc,mt,g) = 0), put i_refurbDecisionYear(sc,g), else put '' ) ;
  if(retireYr(sc,g), put retireYr(sc,g) else put '' ) ;
  if(retireMW(sc,g), put retireMW(sc,g) else put '' ) ;
) ;


* b) Write out generation and transmission investment schedules in a formatted text file (i.e. human-readable)
counter = 0 ;
put invest 'Generation and transmission investment schedules by year' ;
loop(sc,
* Write out transmission investments.
  put /// sc.tl, ': ', sc.te(sc) ;
  put //   'Transmission' / ;
  put @3   'Year' @10 'Project' @25 'From' @40 'To' @55 'FrState' @65 'ToState' @77 'FrmCap' @86 'ToCap' @93 'ActCap' @102 'numBlds' @110 'Free?'
      @116 'ErlyYr' @124 'Project description' ;
  loop((buildSoln(mt),y)$sum(tupg, s2_TXPROJVAR(sc,mt,tupg,y)),
    put / @3 y.tl ;
    loop(transitions(sc,tupg,r,rr,ps,pss)$s2_TXPROJVAR(sc,mt,tupg,y),
      counter = counter + 1 ;
      if(counter = 1, put @10 else put / @10 ) ;
      put tupg.tl @25 r.tl @40 rr.tl @55 ps.tl @65 pss.tl @75 priorTxCap(sc,r,rr,ps):8:1, postTxCap(sc,r,rr,pss):8:1, actualTxCap(sc,mt,r,rr,y):8:1, @100 numYrsToBuildTx(sc,tupg,y):5:0 ;
      if(txFixedComYr(transitions) = 0, put @112 'y' else put @112 'n' ) ;
      if(txFixedComYr(transitions) >= txEarlyComYr(transitions), put @116 txFixedComYr(transitions):6:0 else put @116 txEarlyComYr(transitions):6:0 ) ;
      put @124 tupg.te(tupg) ;
    ) ;
    counter = 0 ;
  ) ;
  counter = 0 ;
* Write out generation investments.
  loop(buildSoln(mt),
    put // 'Generation' / ;
    put @3 'Year' @10 'Plant' @25 'Tech' @40 'SubStn' @55 'Region' @75 'MW' @81 'npMW' @88 'numBlds' @97 'Plant description' ;
    loop(y$sum(g, buildOrRetireMW(sc,g,y)),
      put / @3 y.tl ;
      loop((k,i,r,g)$( mapg_k(sc,g,k) * mapg_i(sc,g,i) * mapg_r(sc,g,r) * buildOrRetireMW(sc,g,y) ),
        counter = counter + 1 ;
        if(counter = 1, put @10 else put / @10 ) ;
        put g.tl @25 k.tl @40 i.tl @55 r.tl @70 buildOrRetireMW(sc,g,y):7:1, i_nameplate(sc,g):8:1 @86 numYrsToBuildPlant(sc,g,y):5:0 @97 g.te(g) ;
      ) ;
      counter = 0 ;
    ) ;
  ) ;
) ;


* c) Write out the build and retirement schedule - in SOO-ready format.
counter = 0 ;
put sooBld ;
loop(sc,
  put sc.te(sc) ;
  loop(activeMT(sc,mt)$buildSoln(mt),
    put / 'Year', 'Plant description', 'Technology description', 'MW', 'Nameplate MW', 'Substation' ;
    loop(y$sum(g, buildOrRetireMW(sc,g,y)),
      put / y.tl ;
      loop((k,g,i)$( mapg_k(sc,g,k) * mapg_i(sc,g,i) * buildOrRetireMW(sc,g,y) ),
        counter = counter + 1 ;
        if(counter = 1,
          put g.te(g), k.te(k), buildOrRetireMW(sc,g,y), i_nameplate(sc,g), i.te(i) ;
          else
          put / '' g.te(g), k.te(k), buildOrRetireMW(sc,g,y), i_nameplate(sc,g), i.te(i) ;
        ) ;
      ) ;
      counter = 0 ;
    ) ;
    put / ;
  ) ;
  put // ;
) ;

* d) Write out the forced builds by scenario - in SOO-ready format (in the same file as SOO build schedules).
counter = 0 ;
soobld.ap = 1 ;
put soobld / 'Summary of forced build dates by SC' /  ;
loop(sc,
  put sc.te(sc) ;
  loop(activeMT(sc,mt)$buildSoln(mt),
    put / 'Year', 'Plant description', 'Technology description', 'MW', 'Nameplate MW', 'Substation' ;
    loop(y$sum(g$( commit(sc,g) * buildOrRetireMW(sc,g,y) ), 1 ),
      put / y.tl ;
      loop((k,g,i)$( mapg_k(sc,g,k) * mapg_i(sc,g,i) * commit(sc,g) * buildOrRetireMW(sc,g,y) ),
        counter = counter + 1 ;
        if(counter = 1,
          put g.te(g), k.te(k), buildOrRetireMW(sc,g,y), i_nameplate(sc,g), i.te(i) ;
          else
          put / '' g.te(g), k.te(k), buildOrRetireMW(sc,g,y), i_nameplate(sc,g), i.te(i) ;
        ) ;
      ) ;
      counter = 0 ;
    ) ;
    put / ;
  ) ;
  put // ;
) ;

* e) Write out a file to create maps of generation plant builds/retirements.
*    NB: In cases of builds over multiple years, the first year is taken as the build year.
put pltgeo ;
put 'sc', 'Plant', 'Substation', 'Tech', 'Fuel', 'FuelGrp', 'subY', 'subX', 'existMW', 'builtMW', 'retiredMW', 'finalMW'
    'BuildYr', 'RetireYr', 'Plant description', 'Tech description', 'Fuel description', 'Fuel group description' ;
loop((sc,g,i,k,f,fg)$( (exist(sc,g) or finalMW(sc,g)) * mapg_i(sc,g,i) * mapg_k(sc,g,k) * mapg_f(sc,g,f) * mapf_fg(sc,f,fg) ),
  put / sc.tl, g.tl, i.tl, k.tl, f.tl, fg.tl, i_substnCoordinates(sc,i,'Northing'), i_substnCoordinates(sc,i,'Easting') ;
  if(exist(sc,g),
    put i_nameplate(sc,g), '', retireMW(sc,g), finalMW(sc,g), '', retireYr(sc,g) ;
    else
    put '', buildMW(sc,g), retireMW(sc,g), finalMW(sc,g), buildYr(sc,g), retireYr(sc,g) ;
  ) ;
  put g.te(g), k.te(k), f.te(f), fg.te(fg) ;
) ;

* f) Write out a file to create maps of transmission upgrades.
put txgeo ;
put 'sc', 'FrReg', 'ToReg', 'FrY', 'ToY', 'FrX', 'ToX', 'priorTxCap', 'postTxCap', 'ActualCap', 'FrSte', 'ToSte', 'Year', 'Project', 'Project description'  ;
* First report the initial network
loop((paths(sc,r,rr),ps)$( sameas(ps,'initial') ),
  put / sc.tl, r.tl, rr.tl ;
  loop((i,ii)$( regionCentroid(sc,i,r) * regionCentroid(sc,ii,rr) ),
    put i_substnCoordinates(sc,i,'Northing'), i_substnCoordinates(sc,ii,'Northing'), i_substnCoordinates(sc,i,'Easting'), i_substnCoordinates(sc,ii,'Easting') ;
  ) ;
  put priorTxCap(paths,ps) ;
) ;
txgeo.ap = 1 ;
* Now add on the upgrades.
loop((sc,buildSoln(mt),tupg,r,rr,ps,pss,y)$( (paths(sc,r,rr) * transitions(sc,tupg,r,rr,ps,pss)) and s2_TXPROJVAR(sc,mt,tupg,y) and txFixedComYr(sc,tupg,r,rr,ps,pss) < 3333 ),
  put / sc.tl, r.tl, rr.tl ;
  loop((i,ii)$( regionCentroid(sc,i,r) * regionCentroid(sc,ii,rr) ),
    put i_substnCoordinates(sc,i,'Northing'), i_substnCoordinates(sc,ii,'Northing'), i_substnCoordinates(sc,i,'Easting'), i_substnCoordinates(sc,ii,'Easting') ;
  ) ;
  put priorTxCap(sc,r,rr,ps), postTxCap(sc,r,rr,pss), actualTxCap(sc,mt,r,rr,y), ps.tl, pss.tl, yearNum(sc,y), tupg.tl, tupg.te(tupg) ;
) ;


*===============================================================================================
* x. Write the solve summary report.

* Message/header strings for use throughout solve summary report: 
$set ModStatx    "++++ Solution is no good - check GEMsolve.lst ++++"
$set ModStat1    "An optimal RMIP solution was obtained"
$set ModStat8    "A valid integer solution was obtained"
$set ModStat18   "An optimal integer solution was obtained"
$set SolveStatx  "++++ The solver exited abnormally - check GEMsolve.lst ++++"
$set SolveStat1  "The solver exited normally"
$set SolveStat3  "The solver exited normally after hitting a resource limit"

$set TmgHeader   " - results pertain to the timing run."
$set ReoHeader   " - results pertain to the re-optimisation run."
$set DisHeader   " - results pertain to the average of the dispatch runs."
$set DisExogHdr  " - decisions were provided to GEM exogenously in the form of a build and retirement schedule."

problems = 0 ; warnings = 0 ;
put ss
  'This report generated at ', system.time, ' on ' system.date  /
  'Search this entire report for 4 plus signs (++++) to identify any important error messages.' ///
  'Scenarios reported on are:' loop(sc, put / @3 sc.tl @15 sc.te(sc) ) ;

$ontext
  @3 'Run type:'                       @37 if(%RunType%=0, put 'GEM and DISP' else if(%RunType% = 1, put 'GEM only' else put 'DISP only')) ; put /
  @3 'Modelled time horizon:'          @37 '%FirstYr%', ' - ', '%LastYr%', '   (', numyears:2:0, ' years)' /
  @3 'Terminal benefit years:'         @37 begtermyrs:<4:0, ' - ', '%LastYr%' /
  @3 'Linear gen build years:'         @37 cgenyr:<4:0, ' onwards.' /
  @3 'Hydro sequences:'                @37 '%FirstInflowYr%', ' - ', '%LastInflowYr%' /
  @3 'Hydro year for timing:'          @37 loop(tmnghydyr(hYr),  put hYr.tl:<8:0
                                             if((not sameas(tmnghydyr,'Multiple')), put '- scaled by ', scaleInflows:4:2 ) ;
                                             if(sameas(tmnghydyr,'Multiple'),
                                               put @47 '- ' loop(scenarios$ ( not sameas(scenarios, 'dum')),  put scenarios.tl, ' ' ) ;
                                               put '- weighted by, respectively,' loop(scenarios$ ( not sameas(scenarios, 'dum')), put scenarioWeight(scenarios) :6:3 ) ) ;
                                           ) ; put /
  @3 'Timing re-optimised?'            @37 if(%RunType%<2 and %SuppressReopt%=0, put 'Yes' else put 'No') ; put /
$                                      if %SuppressReopt%==1 $goto SkipLine
  @3 'Hydro year for re-opt:'          @37 loop(reopthydyr(hYr), put hYr.tl:<8:0 ) ; put /
$                                      label SkipLine
  @3 'DISP hydro years limit:'         @37 (%LimHydYr%):<5:0 /
  @3 'DInflowYr flag:'                 @37 (%DInflowYr%):<5:0 /
  @3 'DInflwYrType flag:'              @37 (%DInflwYrType%):<5:0 /
  @3 'Security criteria:'              @37 if(Security = -1, put 'Security constraints are suppressed'
                                           else if(Security = 0, put 'n' else if(Security = 1, put 'n-1' else put 'n-2' ))) ; put /
  @3 'Reserves modelled?'              @37 if(useresv = 1, put 'Yes' else put 'No' ) ; put /
  @3 'Load growth profile:'            @37 '%GrowthProfile%' /
  @3 'Number load blocks:'             @37 numLBs:<5:0 /
  @3 'VOLL plants unavailable in top'  @37 '%noVOLLblks% load blocks' /
  @3 'Number of technologies:'         @37 numtech:<3:0 /
  @3 'Number of fuels:'                @37 numfuel:<3:0 /
  @3 'Number of owners:'               @37 numowner:<3:0 /
  @3 'Number of substations:'          @37 numsub:<3:0 /
  @3 'Number of regions:'              @37 numreg:<3:0 /
  @3 'Number of zones:'                @37 numzone:<3:0 /
  @3 'Number of Tx paths:'             @37 numpaths:<3:0 /
  @3 'Potential/actual Tx upgrades:'   @37 numupgrades:<3:0 /
  @3 'Network structure:'              @37 if(DCloadflow = 1,   put 'Meshed - solved using DC load flow' ;
                                           else if(numKVLs > 0, put 'Meshed - but forced to be solved as a transportation problem' ;
                                           else                 put 'Radial - solved as a transportation problem' ) ) ;  put /
  @3 'Kirchoff current laws:'          @37 numKCLs:<3:0 /
  @3 'Kirchoff voltage laws:'          @37 numKVLs:<3:0 /
  @3 'Transmission investment?'        @37 if(%RunType%<2 and EndogTx = 1, put 'Endogenous' else put 'Exogenous') ; put /
  @3 'Tx loss function segments:'      @37 (%CtrlPoints% - 1):<3:0 /
  @3 'Depreciation type:'              @37 if(%deptype%=0, put 'Straight line' else put 'Diminishing value' ) ; put /
  @3 'Random capex adjustment:'        @37 'Initial cost +/- ', (100 * %RandomCC%):<4:1, ' percent for technology types: ' loop(randomise(k), put k.tl ', ' ) ; put /
  @3 'Annual MW limit:'                @37 annMW:<5:0 /
  @3 'Partial builds?'                 @37 if(PartGenBld = 1, put 'Yes' else put 'No' ) ; put /
  @3 'Re-opt renew share?'             @37 if(%SprsRenShrReo%=0, put 'Yes' else put 'No' ) ; put /
  @3 'Dispatch renew share?'           @37 if(%SprsRenShrDis%=0, put 'Yes' else put 'No' ) ; put /
  @3 'Market scenarios:'               @37 '%RunMDS%' /
  @3 'LP/MIP/RMIP solver:'             @37 '%Solver%' /
  @3 'GEM solved as a:'                @37 '%GEMtype%' /
  @3 'DISP solved as a:'               @37 '%DISPtype%' /
  @3 'Plotting method:'                @37 if(%MexOrMat%=1, put 'Generate figures using .mex executable'
                                           else put 'Generate figures using Matlab source code' ) ; put /
  @3 'Input plots?'                    @37 if(%PlotInFigures%=1,  put 'Yes' else put 'No' ) ; put /
  @3 'Output plots?'                   @37 if(%PlotOutFigures%=1, put 'Yes' else put 'No' ) ; put /
  @3 'MIPtrace plots?'                 @37 ;
$                                      if %GEMtype%=="rmip" $goto NoTracePlots
                                       if(%PlotMIPtrace%=1, put 'Yes' else put 'No' ) ; put /
$                                      label NoTracePlots
$                                      if not %GEMtype%=="rmip" $goto YesTracePlots
                                       put 'No' ; put /
$                                      label YesTracePlots
  @3 'Restart file name:'              @37 system.rfile /
  @3 'Input file names:'               @37 "%DataPath%%GDXfilename%" ///
$offtext

loop(solveGoal(sc,goal),
  put /// 'Scenario: ' put sc.te(sc), ' (', sc.tl, ') ' / @3
          'Solve goal:' @25 goal.tl:<6, ' - ', goal.te(goal) //

$ if %RunType%==2 $goto NoGEM
* Generate the MIP solve summary information, i.e. timing run and re-optimised run (if it exists).
  loop(activeSolve(sc,mt,hY)$( not sameas(mt,'dis') ),
    if(sameas(mt,'tmg'),  put @3 mt.te(mt) / else put // @3 mt.te(mt) / ) ;
    put @3 'Model status:'  @25 ;
    if(solveReport(sc,mt,hY,goal,'ModStat') = 1, put '%ModStat18%' /
      else if(solveReport(sc,mt,hY,goal,'ModStat') = 8, put '%ModStat8%' /
        else put '%ModStatx%' / ; problems = problems + 1 ;
      ) ;
    ) ;
    put @3 'Solver status:' @25 ;
    if(solveReport(sc,mt,hY,goal,'SolStat') = 1, put '%SolveStat1%' / ;
      else if(solveReport(sc,mt,hY,goal,'SolStat') = 2 or solveReport(sc,mt,hY,goal,'SolStat') = 3, put '%SolveStat3%' / ;
        else put '%SolveStatx%' / ; problems = problems + 1 ;
      ) ;
    ) ; put
    @3 'Number equations:'     @25 solveReport(sc,mt,hY,goal,'Eqns'):<10:0 / 
    @3 'Number variables:'     @25 solveReport(sc,mt,hY,goal,'Vars'):<10:0 / 
    @3 'Number discrete vars:' @25 solveReport(sc,mt,hY,goal,'DVars'):<10:0 / 
    @3 'Number iterations:'    @25 solveReport(sc,mt,hY,goal,'Iter'):<12:0 / 
    @3 'Options file:'         @25 '%Solver%.op', solveReport(sc,mt,hY,goal,'Optfile'):<2:0 /
    @3 'Optcr (%):'            @25 ( 100 * solveReport(sc,mt,hY,goal,'Optcr') ):<6:3 /
    @3 'Gap (%):'              @25 solveReport(sc,mt,hY,goal,'Gap%'):<6:3 /
    @3 'Absolute gap:'         @25 solveReport(sc,mt,hY,goal,'GapAbs'):<10:2 /
    @3 'CPU seconds:'          @25 solveReport(sc,mt,hY,goal,'Time'):<10:0 /
    @3 'Objective fn value:'   @25 s2_TOTALCOST(sc,mt):<10:1 ;
    if(solveReport(sc,mt,hY,goal,'Slacks') = 1, put '  ++++ This solution contains slack variables ++++' / else put / ) ;
    put @9 'Comprised of:' @25 ;
    loop(objc$( ord(objc) > 1 and not (pen(objc) or slk(objc)) ),
      put objComponents(sc,mt,objc):<10:1, @33 '- ', objc.te(objc) / @23 '+ ' ;
    ) ;
    put sum(pen(objc), objComponents(sc,mt,objc)):<10:1, @33 '- Sum of penalty components' / @23 '+ ' ;
    put sum(slk(objc), objComponents(sc,mt,objc)):<10:1, @33 '- Sum of slack components' ;
  ) ;

$ label NoGEM
$ if %RunType%==1 $goto NoDISP
* Generate the RMIP (simulation) solve summary information for each pass around the SC loop.
  counter = 0 ;
  loop(activeSolve(sc,mt,hY)$( sameas(mt,'dis') and counter = 0 ),
    counter = counter + 1 ;
    put /// @3 mt.te(mt) /
    @3 'Number equations:'     @25 solveReport(sc,mt,hY,'','Eqns'):<10:0 / 
    @3 'Number variables:'     @25 solveReport(sc,mt,hY,'','Vars'):<10:0 / 
    @3 'Generation capex'      @25 objComponents(sc,mt,'obj_gencapex'):<10:1 /
    @3 'Refurbishment capex'   @25 objComponents(sc,mt,'obj_refurb'):<10:1 /
    @3 'Transmission capex'    @25 objComponents(sc,mt,'obj_txcapex'):<10:1 /
    @3 'HVDC charges'          @25 objComponents(sc,mt,'obj_hvdc'):<10:1 /
    @3 'Fixed opex'            @25 objComponents(sc,mt,'obj_fixOM'):<10:1 /
    @3 'Objective value in the following simulations (DISP solves) differs only due to after tax discounted' /
    @3 'variable costs, the cost of providing reserves and, possibly, the value of any penalties.' //
  ) ;
  loop(activeSolve(sc,mt,hY)$sameas(mt,'dis'),
    put @3 sc.tl, '. Simulation - ' hY.tl ' hydro year' /
    @3 'Model status:' @25 ;
    if(solveReport(sc,mt,hY,'','ModStat') = 1,  put '%ModStat1%'   / else put '%ModStatx%'   / ; problems = problems + 1 ) ; put @3 'Solver status:' @25 ;
    if(solveReport(sc,mt,hY,'','SolStat') = 1,  put '%SolveStat1%' / else put '%SolveStatx%' / ; problems = problems + 1 ) ; put
    @3 'Number iterations:'    @25 solveReport(sc,mt,hY,'','Iter'):<10:0 / 
    @3 'CPU seconds:'          @25 solveReport(sc,mt,hY,'','Time'):<10:0 / 
    @3 'Objective fn value:'   @25 s2_TOTALCOST(sc,mt):<10:0  ;
    if(solveReport(sc,mt,hY,'','Slacks') = 1, put '  ++++ This solution contains slack variables ++++' / else put / ) ;
    put / ;
  ) ;

$ label NoDisp
* End of writing to solve summary report loop over SC.
) ;


* Write summaries of built, refurbished and retired capacity by technology.
loop(buildSoln(mt),
  loop(a,
    put /// a.te(a) ;
    if( sameas(a,'blt'),
      if(sameas(mt,'tmg'), put '%TmgHeader%' else if(sameas(mt,'reo'), put '%ReoHeader%' else put '%DisExogHdr%' ) ) ;
      else
      if(not sameas(mt,'dis'), put '%TmgHeader%' else put '%DisExogHdr%' ) ;
    ) ;
    loop(activeMT(sc,mt),
      put // @3 sc.te(sc), ' (', sc.tl, ')' /  @58 'Potential MW' @71 'Actual MW' @89 '%' ;
      loop(k$potentialCap(sc,k,a),
        put / @5 k.te(k) @60, potentialCap(sc,k,a):10:0, actualCap(sc,mt,k,a):10:0, actualCapPC(sc,mt,k,a):10:1 ;
      ) ;
    ) ;
  ) ;
) ;


* Write a summary of transmission upgrades.
loop(buildSoln(mt),
  put //// 'Summary of transmission upgrades' ;
  if(not sameas(mt,'dis'), put '%TmgHeader%' else put '%DisHeader%' ) ;
  loop(activeMT(sc,mt),
    put // @3 sc.te(sc), ' (', sc.tl, ')' ;
    put / @5 'Project' @20 'From' @35 'To' @50 'From state' @65 'To state' @80 'Year' @87 'MW Capacity'
    loop((y,transitions(sc,tupg,r,rr,ps,pss))$s2_TXUPGRADE(sc,mt,r,rr,ps,pss,y),
      put / @5 tupg.tl:<15, r.tl:<15, rr.tl:<15, ps.tl:<15, pss.tl:<15, y.tl:<8, actualTxCap(sc,mt,r,rr,y):10:0  ;
    ) ;
  ) ;
) ;


* Write a summary of transmission losses.
loop(buildSoln(mt),
  put //// 'Summary of transmission losses (GWh and as percent of generation)' ;
  if(sameas(mt,'tmg'), put '%TmgHeader%' else if(sameas(mt,'reo'), put '%ReoHeader%' else put '%DisHeader%' ) ) ;
  loop(sc,
    put // @3 sc.te(sc), ' (', sc.tl, ')' ;
    put  / @5 'Generation:'           @28 loop(activeMTOC(sc,mt,scenarios) , put genGWh(sc,mt,scenarios) :10:1 ) ;
    put  / @5 'Intraregional losses:' @28 put intraTxLossGWh(sc):10:1 ; loop(activeMTOC(sc,mt,scenarios) ,  put ( 100 * intraTxLossGWh(sc) / genGWh(sc,mt,scenarios)  ):>7:2, '%  ' ) ;
    put  / @5 'Interregional losses:' @28 loop(activeMTOC(sc,mt,scenarios) , put interTxLossGWh(sc,mt,scenarios) :10:1, ( 100 * interTxLossGWh(sc,mt,scenarios)  / genGWh(sc,mt,scenarios)  ):>7:2, '%  ' ) ;
  ) ;
) ;


* Indicate whether or not there is excessive shortage generation (excessive is assumed to be 3% of generation).
if(sum((activeMTOC(sc,mt,scenarios) ,y,t,lb), xsDeficitGen(sc,mt,scenarios, y,t,lb)) = 0,
  put //// 'There is no excessive use of unserved energy, where excessive is defined to be 3% or more of generation.' ;
  else
  put //// 'Examine "Objective value components and shortage generation.gdx" in the GDX output folder to see' /
           'what years and load blocks had excessive shortage generation (i.e. more than 3% of generation).' ;
) ;


* Write a summary breakdown of objective function values.
loop(buildSoln(mt),
  put //// 'Summary breakdown of objective function values ($m)' ;
  if(sameas(mt,'tmg'), put '%TmgHeader%' else if(sameas(mt,'reo'), put '%ReoHeader%' else put '%DisHeader%' ) ) ;
  loop(activeSolve(sc,mt,hY),
    put // @3 sc.te(sc), ' (', sc.tl, ')' ;
    put /  @5 'Objective function value' @65 s2_TOTALCOST(sc,mt):10:1 ;
    loop(objc$( ord(objc) > 1 and not (pen(objc) or slk(objc)) ),
      put / @5 objc.te(objc), @65 objComponents(sc,mt,objc):10:1 ;
    ) ;
    put / @5 'Sum of penalty components', @65 ( sum(pen(objc), objComponents(sc,mt,objc)) ):10:1 ;
    put / @5 'Sum of slack components',   @65 ( sum(slk(objc), objComponents(sc,mt,objc)) ):10:1 ;
  ) ;
) ;


$ontext
* Probably don't need all this...
$set beginTermYrs  2035 ! Beginning of the sequence of modelled years that are used to represent the period of so-called terminal years.

* Write a note to solve summary report if problems (other than slacks or penalty violations) are present in some solutions, or if warnings are required.
* Figure out the warnings:
* Warning 1
if(%lastYear% - %beginTermYrs% < 3, warnings = warnings + 1 ) ;
* Warning 2
counter = 0 ;
loop((g,sc)$( ( erlyComYr(g,sc) > 1 ) * ( fixComYr(g,sc) > 1 ) * ( fixComYr(g,sc) < erlyComYr(g,sc) ) ),
  counter  = counter + 1 ;
  warnings = warnings + 1 ;
) ;
if(warnings > 0,
  put ss ////
  '  ++++ WARNINGS ++++' // ;
  if(%lastYear% - %beginTermYrs% < 3,
    put '  Terminal years begin in %beginTermYrs% whereas the last modelled year is ', lastYear:<4:0, ' (although GEM changed %beginTermYrs% to '
    begtermyrs:<4:0, ' and just carried on anyway). Check value of beginTermYrs.' / ;
  ) ;
  if(counter > 0,
    put '  Some fixed plant commissioning years precede the earliest commissioning year. Examine badComYr in %BaseOutName%.lst.' / ;
  ) ;
) ;

if(problems > 0,
  put ////
  '  ++++ PROBLEMS OTHER THAN SLACKS OR PENALTIES EXIST WITH SOME SOLUTIONS ++++' /
  '  It could be that a model is infeasible or the solver has not exited        ' /
  '  normally for some reason. Examine this solve summary report (search        ' /
  '  for ++++) or GEMsolve.log for additional information and resolve before    ' /
  '  proceeding.                                                                ' //// ;
) ;
$offtext

*===============================================================================================
* x. Xxx.

Execute_Unload '%OutPath%\%runName%\GDX\%runName% - Objective value components and shortage generation.gdx',
  objComponentsYr, objComponents, deficitGen, xsDeficitGen  ;



* Write a final time stamp in the solve summary report file
ss.ap = 1 ;
putclose ss //// "GEMreports has now finished..." / "Time: " system.time / "Date: " system.date ;



$stop
$ontext
From this point forward is stuff from the old GEMreports.

 Code sections:
  1. Load the data required to generate reports from the GDX files.
  2. Declare the sets and parameters local to GEMreports.
  3. Perform the various calculations required to generate reports.
  4. Write out the summary results report.
  5. Write out the generation and transmission investment schedules in various formats.
     a) Build, refurbishment and retirement data and scenarios in easy to read format suitable for importing into Excel.
     b) Write out generation and transmission investment schedules in a formatted text file (i.e. human-readable)
     c) Write out the build and retirement schedule - in SOO-ready format.
     d) Write out the forced builds by SC - in SOO-ready format (in the same file as SOO build schedules).
     e) Build schedule in GAMS-readable format - only write this file if GEM was run (i.e. skip it if RunType = 2).
     f) Write out a file to create maps of generation plant builds/retirements.
     g) Write out a file to create maps of transmission upgrades.
  6. Write out various summaries of the MW installed net of retirements.
  7. Write out various summaries of activity associated with peaking plant.
  8. Write out the GIT summary results.
  9. Write a report of HVDC charges sliced and diced all different ways.
 10. Write a report of features common to all scenarios.
 11. Write out a file of miscellaneous scalars - to pass to Matlab.
 12. Write out the mapping of inflow years to modelled years.
 13. Collect national generation, transmission, losses and load (GWh) into a single parameter.
 14. Write the solve summary report.
 15. Report the presence of penalty or slack (i.e. violation) variables (if any).
 16. Dump certain parameters into GDX files for use in subsequent programs, e.g. GEMplots and GEMaccess.
$offtext

Sets
* Capacity
  pkrs_plus20(sc,mt,scenarios,g)                 'Identify peakers that produce 20% or more energy in a year than they are theoretically capable of'
  noPkr_minus20(sc,mt,scenarios,g)               'Identify non-peakers that produce less than 20% of the energy in a year than they are theoretically capable of'

* GIT analysis
  cy        'Class of years'
             / git            'Years entering the GIT analysis'
               trm            'Terminal years' /
  item      'Item of GIT analysis'
             / itm1           'Capex (generation plant) before depreciation tax credit, $m PV'
               itm2           'Fixed Opex before tax, $m PV'
               itm3           'HVDC charge before tax, $m PV'
               itm4           'Variable Opex before tax, $m PV'
               itm5           'Capex (generation plant) after depreciation tax credit, $m PV'
               itm6           'Fixed Opex after tax, $m PV'
               itm7           'HVDC charge after tax, $m PV'
               itm8           'Variable Opex after tax, $m PV'
               itm9           'Capex (transmission equipment) before depreciation tax credit, $m PV'
               itm10          'Capex (transmission equipment) after depreciation tax credit, $m PV'
               itmA           'Generation fixed benefits (A)'
               itmB           'Generation variable benefits (B)'
               itmC           'Transmission costs (C)'
               itmD           'Terminal benefits (D)'
               itmE           'Expected net markets benefit (A+B-C+D)'  /
  git(cy)   'Years entering the GIT analysis'    / git /
  trm(cy)   'Terminal years'                     / trm /
  gityrs(y) 'GIT analysis years'
  trmyrs(y) 'Terminal period years'
  mapcy_y(cy,y) 'Map modelled years into year classes'

* Analysis of features common to all scenarios solved.
  buildall(g)              'Identify all plant built in all scenarios'
  buildall_sameyr(g)       'Identify all plant built in the same year in all scenarios'
  buildall_notsameyr(g)    'Identify all plant built in all scenarios but in different years in at least two scenarios'
  build_close5(g,sc,scs) 'A step to identifying all plant built within 5 years of each other (but not in the same year) in all scenarios'
  buildclose5(g)           'Identify all plant built within 5 years of each other (but not in the same year) in all scenarios'
  buildplus5(g)            'Identify all plant built in all scenarios where the build year is more than 5 years apart'
  ;

Parameters
  GITresults(item,d,sc,dt,cy)                   'GIT analysis summary'
  Chktotals(sc,mt,*)                            'Calculate national generation, transmission, losses and load, GWh'

* Items common to all SCs (where more than one SC is solved)
  numSC_fact                                    '(NumSC)!'
  numSC_fact2                                   '(NumSC - 2)!'
  numCombos                                     'numSC_fact / 2 * numSC_fact2, i.e. the number of ways of picking k unordered scenarios from n possibilities'
  retiresame(sc,g,y)                            'MW retired and year retired is the same across all SCs'
  refurbsame(sc,g)                              'Refurbishment year is the same across all SCs'
  txupgradesame(sc,tupg,y)                      'Transmission upgrade and upgrade year is the same across all SCs'

* Reserves
  totalresvviol(sc,mt,rc,scenarios)               'Total energy reserves violation, MW (to be written into results summary report)'

* Generation capex
  capchrg_r(sc,mt,g,y)                           'Capex charges (net of depreciation tax credit effects) by built plant by year, $m (real)'
  capchrg_pv(sc,mt,g,y,d)                        'Capex charges (net of depreciation tax credit effects) by built plant by year, $m (present value)'
  capchrgyr_r(sc,mt,y)                           'Capex charges on built plant (net of depreciation tax credit effects) by year, $m (real)'
  capchrgyr_pv(sc,mt,y,d)                        'Capex charges on built plant (net of depreciation tax credit effects) by year, $m (present value)'
  capchrgplt_r(sc,mt,g)                          'Capex charges (net of depreciation tax credit effects) by plant, $m (real)'
  capchrgplt_pv(sc,mt,g,d)                       'Capex charges (net of depreciation tax credit effects) by plant, $m (present value)'
  capchrgtot_r(sc,mt)                            'Total capex charges on built plant (net of depreciation tax credit effects), $m (real)'
  capchrgtot_pv(sc,mt,d)                         'Total capex charges on built plant (net of depreciation tax credit effects), $m (present value)'

  taxcred_r(sc,mt,g,y)                           'Tax credit on depreciation by built plant by year, $m (real)'
  taxcred_pv(sc,mt,g,y,d)                        'Tax credit on depreciation by built plant by year, $m (present value)'
  taxcredyr_r(sc,mt,y)                           'Tax credit on depreciation of built plant by year, $m (real)'
  taxcredyr_pv(sc,mt,y,d)                        'Tax credit on depreciation of built plant by year, $m (present value)'
  taxcredplt_r(sc,mt,g)                          'Tax credit on depreciation by plant, $m (real)'
  taxcredplt_pv(sc,mt,g,d)                       'Tax credit on depreciation by plant, $m (present value)'
  taxcredtot_r(sc,mt)                            'Total tax credit on depreciation of built plant, $m (real)'
  taxcredtot_pv(sc,mt,d)                         'Total tax credit on depreciation of built plant, $m (present value)'

* Generation plant fixed costs
  fopexgross_r(sc,mt,g,y,t)                      'Fixed O&M expenses (before tax benefit) by built plant by year by period, $m (real)'
  fopexgross_pv(sc,mt,g,y,t,d)                   'Fixed O&M expenses (before tax benefit) by built plant by year by period, $m (present value)'
  fopexnet_r(sc,mt,g,y,t)                        'Fixed O&M expenses (after tax benefit) by built plant by year by period, $m (real)'
  fopexnet_pv(sc,mt,g,y,t,d)                     'Fixed O&M expenses (after tax benefit) by built plant by year by period, $m (present value)'
  fopexgrosstot_r(sc,mt)                         'Total fixed O&M expenses (before tax benefit), $m (real)'
  fopexgrosstot_pv(sc,mt,d)                      'Total fixed O&M expenses (before tax benefit), $m (present value)'
  fopexnettot_r(sc,mt)                           'Total fixed O&M expenses (after tax benefit), $m (real)'
  fopexnettot_pv(sc,mt,d)                        'Total fixed O&M expenses (after tax benefit), $m (present value)'

* Generation plant HVDC costs
  hvdcgross_r(sc,mt,g,y,t)                       'HVDC charges (before tax benefit) by built plant by year by period, $m (real)'
  hvdcgross_pv(sc,mt,g,y,t,d)                    'HVDC charges (before tax benefit) by built plant by year by period, $m (present value)'
  hvdcnet_r(sc,mt,g,y,t)                         'HVDC charges (after tax benefit) by built plant by year by period, $m (real)'
  hvdcnet_pv(sc,mt,g,y,t,d)                      'HVDC charges (after tax benefit) by built plant by year by period, $m (present value)'
  hvdcgrosstot_r(sc,mt)                          'Total HVDC charges (before tax benefit), $m (real)'
  hvdcgrosstot_pv(sc,mt,d)                       'Total HVDC charges (before tax benefit), $m (present value)'
  hvdcnettot_r(sc,mt)                            'Total HVDC charges (after tax benefit), $m (real)'
  hvdcnettot_pv(sc,mt,d)                         'Total HVDC charges (after tax benefit), $m (present value)'

* Generation plant total SRMCs
  vopexgross_r(sc,mt,g,y,t,scenarios)             'Variable O&M expenses with LF adjustment (before tax benefit) by built plant by year by period, $m (real)'
  vopexgross_pv(sc,mt,g,y,t,scenarios,d)          'Variable O&M expenses with LF adjustment (before tax benefit) by built plant by year by period, $m (present value)'
  vopexnet_r(sc,mt,g,y,t,scenarios)               'Variable O&M expenses with LF adjustment (after tax benefit) by built plant by year by period, $m (real)'
  vopexnet_pv(sc,mt,g,y,t,scenarios,d)            'Variable O&M expenses with LF adjustment (after tax benefit) by built plant by year by period, $m (present value)'
  vopexgrosstot_r(sc,mt,scenarios)                'Total variable O&M expenses with LF adjustment (before tax benefit), $m (real)'
  vopexgrosstot_pv(sc,mt,scenarios,d)             'Total variable O&M expenses with LF adjustment (before tax benefit), $m (present value)'
  vopexnettot_r(sc,mt,scenarios)                  'Total variable O&M expenses with LF adjustment (after tax benefit), $m (real)'
  vopexnettot_pv(sc,mt,scenarios,d)               'Total variable O&M expenses with LF adjustment (after tax benefit), $m (present value)'

  vopexgrossnolf_r(sc,mt,g,y,t,scenarios)         'Variable O&M expenses without LF adjustment (before tax benefit) by built plant by year by period, $m (real)'
  vopexgrossnolf_pv(sc,mt,g,y,t,scenarios,d)      'Variable O&M expenses without LF adjustment (before tax benefit) by built plant by year by period, $m (present value)'
  vopexnetnolf_r(sc,mt,g,y,t,scenarios)           'Variable O&M expenses without LF adjustment (after tax benefit) by built plant by year by period, $m (real)'
  vopexnetnolf_pv(sc,mt,g,y,t,scenarios,d)        'Variable O&M expenses without LF adjustment (after tax benefit) by built plant by year by period, $m (present value)'
  vopexgrosstotnolf_r(sc,mt,scenarios)            'Total variable O&M expenses without LF adjustment (before tax benefit), $m (real)'
  vopexgrosstotnolf_pv(sc,mt,scenarios,d)         'Total variable O&M expenses without LF adjustment (before tax benefit), $m (present value)'
  vopexnettotnolf_r(sc,mt,scenarios)              'Total variable O&M expenses without LF adjustment (after tax benefit), $m (real)'
  vopexnettotnolf_pv(sc,mt,scenarios,d)           'Total variable O&M expenses without LF adjustment (after tax benefit), $m (present value)'

* Transmission equipment capex
  txcapchrg_r(sc,mt,r,rr,ps,y)                   'Transmission capex charges (net of depreciation tax credit effects) by built equipment by year, $m (real)'
  txcapchrg_pv(sc,mt,r,rr,ps,y,d)                'Transmission capex charges (net of depreciation tax credit effects) by built equipment by year, $m (present value)'
  txcapchrgyr_r(sc,mt,y)                         'Transmission capex charges (net of depreciation tax credit effects) by year, $m (real)'
  txcapchrgyr_pv(sc,mt,y,d)                      'Transmission capex charges (net of depreciation tax credit effects) by year, $m (present value)'
  txcapchrgeqp_r(sc,mt,r,rr,ps)                  'Transmission capex charges (net of depreciation tax credit effects) by equipment, $m (real)'
  txcapchrgeqp_pv(sc,mt,r,rr,ps,d)               'Transmission capex charges (net of depreciation tax credit effects) by equipment, $m (present value)'
  txcapchrgtot_r(sc,mt)                          'Total transmission capex charges (net of depreciation tax credit effects), $m (real)'
  txcapchrgtot_pv(sc,mt,d)                       'Total transmission capex charges (net of depreciation tax credit effects), $m (present value)'

  txtaxcred_r(sc,mt,r,rr,ps,y)                   'Tax credit on depreciation by built transmission equipment by year, $m (real)'
  txtaxcred_pv(sc,mt,r,rr,ps,y,d)                'Tax credit on depreciation by built transmission equipment by year, $m (present value)'
  txtaxcredyr_r(sc,mt,y)                         'Tax credit on depreciation on transmission equipment by year, $m (real)'
  txtaxcredyr_pv(sc,mt,y,d)                      'Tax credit on depreciation on transmission equipment by year, $m (present value)'
  txtaxcredeqp_r(sc,mt,r,rr,ps)                  'Tax credit on depreciation by transmission equipment, $m (real)'
  txtaxcredeqp_pv(sc,mt,r,rr,ps,d)               'Tax credit on depreciation by transmission equipment, $m (present value)'
  txtaxcredtot_r(sc,mt)                          'Total tax credit on depreciation of transmission equipment, $m (real)'
  txtaxcredtot_pv(sc,mt,d)                       'Total tax credit on depreciation of transmission equipment, $m (present value)'   ;



*===============================================================================================
* 3. Perform the various calculations required to generate reports.


loop(activeMT(sc,mt),

* Capacity and dispatch
  blah blah blah

* Calculations that relate only to the run type in which capacity expansion/contraction decisions are made.
    blah blah blah
   
* End of capacity expansion/contraction calculations.
  ) ;

  blah blah blah

* Reserves
  totalresvviol(sc,mt,rc,scenarios) $activeMTOC(sc,mt,scenarios)  = sum((ild,y,t,lb), s2_RESVVIOL(sc,mt,rc,ild,y,t,lb,scenarios)  ) ;

* Generation capex
  capchrg_r(sc,mt,g,y)    = 1e-6 * capchargem(g,y,sc) * s2_capacity(sc,mt,g,y) ;
  capchrg_pv(sc,mt,g,y,d) = sum(firstPeriod(t), PVfacsM(y,t,d) * capchrg_r(sc,mt,g,y)) ;

  capchrgyr_r(sc,mt,y)    = sum(g, capchrg_r(sc,mt,g,y)) ;
  capchrgyr_pv(sc,mt,y,d) = sum(g, capchrg_pv(sc,mt,g,y,d)) ;

  capchrgplt_r(sc,mt,g)    = sum(y, capchrg_r(sc,mt,g,y)) ;
  capchrgplt_pv(sc,mt,g,d) = sum(y, capchrg_pv(sc,mt,g,y,d)) ;

  capchrgtot_r(sc,mt)    = sum((g,y), capchrg_r(sc,mt,g,y)) ;
  capchrgtot_pv(sc,mt,d) = sum((g,y), capchrg_pv(sc,mt,g,y,d)) ;

  taxcred_r(sc,mt,g,y)    = 1e-6 * sum(mapg_k(g,k), deptcrecfac(y,k,'genplt') * capcostm(g,sc) * s2_capacity(sc,mt,g,y)) ;
  taxcred_pv(sc,mt,g,y,d) = sum(firstPeriod(t), PVfacsM(y,t,d) * taxcred_r(sc,mt,g,y)) ;

  taxcredyr_r(sc,mt,y)    = sum(g, taxcred_r(sc,mt,g,y)) ;
  taxcredyr_pv(sc,mt,y,d) = sum(g, taxcred_pv(sc,mt,g,y,d)) ;

  taxcredplt_r(sc,mt,g)    = sum(y, taxcred_r(sc,mt,g,y)) ;
  taxcredplt_pv(sc,mt,g,d) = sum(y, taxcred_pv(sc,mt,g,y,d)) ;

  taxcredtot_r(sc,mt)    = sum((g,y), taxcred_r(sc,mt,g,y)) ;
  taxcredtot_pv(sc,mt,d) = sum((g,y), taxcred_pv(sc,mt,g,y,d)) ;

* Generation plant fixed costs
  fopexgross_r(sc,mt,g,y,t)    = 1e-6 * ( 1/card(t) ) * fixedOM(g) * s2_capacity(sc,mt,g,y) ;
  fopexgross_pv(sc,mt,g,y,t,d) = PVfacsM(y,t,d) * fopexgross_r(sc,mt,g,y,t) ;
  fopexnet_r(sc,mt,g,y,t)      = (1 - i_taxRate)  * fopexgross_r(sc,mt,g,y,t) ;
  fopexnet_pv(sc,mt,g,y,t,d)   = PVfacsM(y,t,d) * fopexnet_r(sc,mt,g,y,t) ;

  fopexgrosstot_r(sc,mt)    = sum((g,y,t), fopexgross_r(sc,mt,g,y,t)) ;
  fopexgrosstot_pv(sc,mt,d) = sum((g,y,t), fopexgross_pv(sc,mt,g,y,t,d)) ;
  fopexnettot_r(sc,mt)      = sum((g,y,t), fopexnet_r(sc,mt,g,y,t)) ;
  fopexnettot_pv(sc,mt,d)   = sum((g,y,t), fopexnet_pv(sc,mt,g,y,t,d)) ; 

* Generation plant HVDC costs
  hvdcgross_r(sc,mt,g,y,t) =  1e-6 *
    ( 1/card(t) ) * sum((k,o)$( ( not demandGen(sc,k) ) * sigen(g) * posbuildm(g,sc) * mapg_k(g,k) * mapg_o(g,o) ), HVDCshr(o) * HVDCchargem(y,sc) * s2_capacity(sc,mt,g,y)) ;
  hvdcgross_pv(sc,mt,g,y,t,d) = PVfacsM(y,t,d) * hvdcgross_r(sc,mt,g,y,t) ;
  hvdcnet_r(sc,mt,g,y,t)      = (1 - i_taxRate)  * hvdcgross_r(sc,mt,g,y,t) ;
  hvdcnet_pv(sc,mt,g,y,t,d)   = PVfacsM(y,t,d) * hvdcnet_r(sc,mt,g,y,t) ;

  hvdcgrosstot_r(sc,mt)    = sum((g,y,t), hvdcgross_r(sc,mt,g,y,t)) ;
  hvdcgrosstot_pv(sc,mt,d) = sum((g,y,t), hvdcgross_pv(sc,mt,g,y,t,d)) ;
  hvdcnettot_r(sc,mt)      = sum((g,y,t), hvdcnet_r(sc,mt,g,y,t)) ;
  hvdcnettot_pv(sc,mt,d)   = sum((g,y,t), hvdcnet_pv(sc,mt,g,y,t,d)) ;

* Generation plant total SRMCs
  vopexgross_r(sc,mt,g,y,t,scenarios)$activeMTOC(sc,mt,scenarios)   = 1e-3 * sum((mapg_e(g,e),lb), SRMC(g,y) * s2_gen(sc,mt,g,y,t,lb,scenarios)  * locFac_Recip(e) ) ;
  vopexgross_pv(sc,mt,g,y,t,scenarios,d)$activeMTOC(sc,mt,scenarios)       = PVfacsM(y,t,d) * vopexgross_r(sc,mt,g,y,t,scenarios)  ;
  vopexnet_r(sc,mt,g,y,t,scenarios)$activeMTOC(sc,mt,scenarios)     = (1 - i_taxRate)  * vopexgross_r(sc,mt,g,y,t,scenarios)  ;
  vopexnet_pv(sc,mt,g,y,t,scenarios,d)$activeMTOC(sc,mt,scenarios)  = PVfacsM(y,t,d) * vopexnet_r(sc,mt,g,y,t,scenarios)  ;

  vopexgrosstot_r(sc,mt,scenarios)$activeMTOC(sc,mt,scenarios)      = sum((g,y,t), vopexgross_r(sc,mt,g,y,t,scenarios) ) ;
  vopexgrosstot_pv(sc,mt,scenarios,d)$activeMTOC(sc,mt,scenarios)   = sum((g,y,t), vopexgross_pv(sc,mt,g,y,t,scenarios, d)) ;
  vopexnettot_r(sc,mt,scenarios)$activeMTOC(sc,mt,scenarios)        = sum((g,y,t), vopexnet_r(sc,mt,g,y,t,scenarios) ) ;
  vopexnettot_pv(sc,mt,scenarios,d)$activeMTOC(sc,mt,scenarios)     = sum((g,y,t), vopexnet_pv(sc,mt,g,y,t,scenarios, d)) ;

  vopexgrossNoLF_r(sc,mt,g,y,t,scenarios)$activeMTOC(sc,mt,scenarios)      = 1e-3 * SRMC(g,y) * sum(lb, s2_gen(sc,mt,g,y,t,lb,scenarios) ) ;
  vopexgrossNoLF_pv(sc,mt,g,y,t,scenarios,d)$activeMTOC(sc,mt,scenarios)   = PVfacsM(y,t,d) * vopexgrossNoLF_r(sc,mt,g,y,t,scenarios)  ;
  vopexnetNoLF_r(sc,mt,g,y,t,scenarios)$activeMTOC(sc,mt,scenarios) = (1 - i_taxRate)  * vopexgrossNoLF_r(sc,mt,g,y,t,scenarios)  ;
  vopexnetNoLF_pv(sc,mt,g,y,t,scenarios,d)$activeMTOC(sc,mt,scenarios)     = PVfacsM(y,t,d) * vopexnetNoLF_r(sc,mt,g,y,t,scenarios)  ;

  vopexgrosstotNoLF_r(sc,mt,scenarios)$activeMTOC(sc,mt,scenarios)  = sum((g,y,t), vopexgrossNoLF_r(sc,mt,g,y,t,scenarios) ) ;
  vopexgrosstotNoLF_pv(sc,mt,scenarios,d)$activeMTOC(sc,mt,scenarios)      = sum((g,y,t), vopexgrossNoLF_pv(sc,mt,g,y,t,scenarios, d)) ;
  vopexnettotNoLF_r(sc,mt,scenarios)$activeMTOC(sc,mt,scenarios)    = sum((g,y,t), vopexnetNoLF_r(sc,mt,g,y,t,scenarios) ) ;
  vopexnettotNoLF_pv(sc,mt,scenarios,d)$activeMTOC(sc,mt,scenarios) = sum((g,y,t), vopexnetNoLF_pv(sc,mt,g,y,t,scenarios, d)) ;

* Transmission equipment capex
  txcapchrg_r(sc,mt,allowedStates(sc,r,rr,ps),y) = 0 ;
  loop(y,
    txcapchrg_r(sc,mt,paths,ps,y) = txcapchrg_r(sc,mt,paths,ps,y-1) + sum(trntxps(paths,pss,ps), txcapcharge(paths,ps,y) * s2_txupgrade(sc,mt,paths,pss,ps,y) ) ;
  ) ;
  txcapchrg_pv(sc,mt,allowedStates(sc,r,rr,ps),y,d) = sum(firstPeriod(t), PVfacsM(y,t,d) * txcapchrg_r(sc,mt,allowedStates(sc,r,rr,ps),y)) ;

  txcapchrgyr_r(sc,mt,y)    = sum(allowedStates(sc,r,rr,ps), txcapchrg_r(sc,mt,allowedStates(sc,r,rr,ps),y)) ;
  txcapchrgyr_pv(sc,mt,y,d) = sum(allowedStates(sc,r,rr,ps), txcapchrg_pv(sc,mt,allowedStates(sc,r,rr,ps),y,d)) ;

  txcapchrgeqp_r(sc,mt,allowedStates(sc,r,rr,ps))    = sum(y, txcapchrg_r(sc,mt,allowedStates(sc,r,rr,ps),y)) ;
  txcapchrgeqp_pv(sc,mt,allowedStates(sc,r,rr,ps),d) = sum(y, txcapchrg_pv(sc,mt,allowedStates(sc,r,rr,ps),y,d)) ;

  txcapchrgtot_r(sc,mt)    = sum((allowedStates(sc,r,rr,ps),y), txcapchrg_r(sc,mt,allowedStates(sc,r,rr,ps),y)) ;
  txcapchrgtot_pv(sc,mt,d) = sum((allowedStates(sc,r,rr,ps),y), txcapchrg_pv(sc,mt,allowedStates(sc,r,rr,ps),y,d)) ;

  txtaxcred_r(sc,mt,allowedStates(sc,r,rr,ps),y)    = txdeptcrecfac(y) * txcapcost(allowedStates(sc,r,rr,ps)) * s2_btx(sc,mt,allowedStates(sc,r,rr,ps),y) ;
  txtaxcred_pv(sc,mt,allowedStates(sc,r,rr,ps),y,d) = sum(firstPeriod(t), PVfacsM(y,t,d) * txtaxcred_r(sc,mt,allowedStates(sc,r,rr,ps),y)) ;

  txtaxcredyr_r(sc,mt,y)    = sum(allowedStates(sc,r,rr,ps), txtaxcred_r(sc,mt,allowedStates(sc,r,rr,ps),y)) ;
  txtaxcredyr_pv(sc,mt,y,d) = sum(allowedStates(sc,r,rr,ps), txtaxcred_pv(sc,mt,allowedStates(sc,r,rr,ps),y,d)) ;

  txtaxcredeqp_r(sc,mt,allowedStates(sc,r,rr,ps))    = sum(y, txtaxcred_r(sc,mt,allowedStates(sc,r,rr,ps),y)) ;
  txtaxcredeqp_pv(sc,mt,allowedStates(sc,r,rr,ps),d) = sum(y, txtaxcred_pv(sc,mt,allowedStates(sc,r,rr,ps),y,d)) ;

  txtaxcredtot_r(sc,mt)    = sum((allowedStates(sc,r,rr,ps),y), txtaxcred_r(sc,mt,allowedStates(sc,r,rr,ps),y)) ;
  txtaxcredtot_pv(sc,mt,d) = sum((allowedStates(sc,r,rr,ps),y), txtaxcred_pv(sc,mt,allowedStates(sc,r,rr,ps),y,d)) ;

) ;


*===============================================================================================
* 4. Write out the summary results report.

put rep "Results summary for '" system.title "' generated on " system.date ' at ' system.time / ;

put //  'Existing capacity (includes DSM and IL, and excludes shortage), MW' / @30 ;
loop(sc_sim(sc), put sc.tl:>12 ) put / @30 loop(sc_sim(sc), put totalExistMW(sc):12:1 ) ;

put /// 'Existing DSM and IL capacity, MW' / @30 loop(sc_sim(sc), put sc.tl:>12 ) put / @30 ;
loop(sc_sim(sc), put totalExistDSM(sc):12:1 ) ;

put /// 'Installed new capacity (includes DSM and IL), MW' / @30 loop(sc_sim(sc), put sc.tl:>12 ) put / @30 ;
loop(sc_sim(sc), put totalBuiltMW(sc):12:1 ) ;

put /// 'Installed new DSM and IL capacity, MW' / @30 loop(sc_sim(sc), put sc.tl:>12 ) put / @30 ;
loop(sc_sim(sc), put totalBuiltDSM(sc):12:1 ) ;

put /// 'Retired capacity, MW' / @30 loop(sc_sim(sc), put sc.tl:>12 ) put / @30 ;
loop(sc_sim(sc), put totalRetiredMW(sc):12:1 ) ;

put /// 'Generation (includes DSM, IL, and Shortage), TWh' / @30 loop(sc_sim(sc), put sc.tl:>12 ) ;
loop((mt,scenarios) $sum(sc, genTWh(sc,mt,scenarios) ),
  put / mt.tl @18 if(sameas(scenarios, 'dum'), put @30 else put scenarios.tl, (100 * i_scenarioWeight(sc,scenarios) ):8:2, @30 ) ;
  loop(sc_sim(sc), put genTWh(sc,mt,scenarios) :12:1 ) ;
) ;

put /// "'Generation' by DSM and IL, GWh" / @30 loop(sc_sim(sc), put sc.tl:>12 ) ;
loop((mt,scenarios) $sum(sc, genDSM(sc,mt,scenarios) ),
  put / mt.tl @18 if(sameas(scenarios, 'dum'), put @30 else put scenarios.tl, (100 * i_scenarioWeight(sc,scenarios) ):8:2, @30 ) ;
  loop(sc_sim(sc), put genDSM(sc,mt,scenarios) :12:1 ) ;
) ;

put /// 'Unserved energy (shortage generation), GWh' / @30 loop(sc_sim(sc), put sc.tl:>12 ) ;
loop((mt,scenarios) $sum((sc,y), defgenYr(sc,mt,scenarios, y)),
  put / mt.tl @18 if(sameas(scenarios, 'dum'), put @30 else put scenarios.tl, (100 * i_scenarioWeight(sc,scenarios) ):8:2, @30 ) ;
  loop(sc_sim(sc), put (sum(y, defgenYr(sc,mt,scenarios, y))):12:1 ) ;
) ;

put /// 'Generation by peakers, GWh' / @30 loop(sc_sim(sc), put sc.tl:>12 ) ;
loop((mt,scenarios) $sum(sc, genPeaker(sc,mt,scenarios) ),
  put / mt.tl @18 if(sameas(scenarios, 'dum'), put @30 else put scenarios.tl, (100 * i_scenarioWeight(sc,scenarios) ):8:2, @30 ) ;
  loop(sc_sim(sc), put  genPeaker(sc,mt,scenarios) :12:1 ) ;
) ;

put /// 'Transmission losses, GWh' / @30 loop(sc_sim(sc), put sc.tl:>12 ) ;
loop((mt,scenarios) $sum(sc, interTxLossGWh(sc,mt,scenarios) ),
  put / mt.tl @18 if(sameas(scenarios, 'dum'), put @30 else put scenarios.tl, (100 * i_scenarioWeight(sc,scenarios) ):8:2, @30 ) ;
  loop(sc_sim(sc), put  interTxLossGWh(sc,mt,scenarios) :12:1 ) ;
) ;

put /// 'Total energy reserve violation, MWh' / @30 ; loop(sc_sim(sc), put sc.tl:>12 ) ;
loop(mt$sum(sc, sc_rt(sc,mt)),
  put / ;
  if(tmg(mt), put 'Timing' else if(reo(mt), put 'Re-optimised' else put 'Dispatch' ) ) ;
  put @17 'Reserve class' ;
  loop((rc,scenarios) $(sum(sc, sc_rt(sc,mt)) and sum(sc, totalresvviol(sc,mt,rc,scenarios) )),
    put / @27 rc.tl if(sameas(scenarios, 'dum'), put @30 else put scenarios.tl, (100 * i_scenarioWeight(sc,scenarios) ):8:2, @30 ) ;
    loop(sc_sim(sc), put totalresvviol(sc,mt,rc,scenarios) :12:1 ) ;
  ) ;
) ;

put /// 'Total capex charges - before deducting depreciation tax credit effects, $m (present value)' / @30 ;
loop(sc_sim(sc), put sc.tl:>12 ) ;
loop(mt$sum(sc, sc_rt(sc,mt)),
  put / ;
  if(tmg(mt), put 'Timing' else if(reo(mt), put 'Re-optimised' else put 'Dispatch' ) ) ;
  put @27 'PV%' ;
  loop(d,
    put / @26 (100 * GITdisc(d)):4:1 @30 ;
    loop(sc_sim(sc), put ( capchrgtot_pv(sc,mt,d) + taxcredtot_pv(sc,mt,d) ):12:1 ) ;
  ) ;
) ;

put /// 'Total capex charges - net of depreciation tax credit effects, $m (present value)' / @30 ;
loop(sc_sim(sc), put sc.tl:>12 ) ;
loop(mt$sum(sc, sc_rt(sc,mt)),
  put / ;
  if(tmg(mt), put 'Timing' else if(reo(mt), put 'Re-optimised' else put 'Dispatch' ) ) ;
  put @27 'PV%' ;
  loop(d,
    put / @26 (100 * GITdisc(d)):4:1 @30 ;
    loop(sc_sim(sc), put capchrgtot_pv(sc,mt,d):12:1 ) ;
  ) ;
) ;

put /// 'Total fixed O&M expenses - before deducting tax, $m (present value)' / @30 ; loop(sc_sim(sc), put sc.tl:>12 ) ;
loop(mt$sum(sc, sc_rt(sc,mt)),
  put / ;
  if(tmg(mt), put 'Timing' else if(reo(mt), put 'Re-optimised' else put 'Dispatch' ) ) ;
  put @27 'PV%' ;
  loop(d,
    put / @26 (100 * GITdisc(d)):4:1 @30 ;
    loop(sc_sim(sc), put fopexgrosstot_pv(sc,mt,d):12:1 ) ;
  ) ;
) ;

put /// 'Total fixed O&M expenses - net of tax, $m (present value)' / @30 ; loop(sc_sim(sc), put sc.tl:>12 ) ;
loop(mt$sum(sc, sc_rt(sc,mt)),
  put / ;
  if(tmg(mt), put 'Timing' else if(reo(mt), put 'Re-optimised' else put 'Dispatch' ) ) ;
  put @27 'PV%' ;
  loop(d,
    put / @26 (100 * GITdisc(d)):4:1 @30 ;
    loop(sc_sim(sc), put fopexnettot_pv(sc,mt,d):12:1 ) ;
  ) ;
) ;

put /// 'Total HVDC charges - before deducting tax, $m (present value)' / @30 ; loop(sc_sim(sc), put sc.tl:>12 ) ;
loop(mt$sum(sc, sc_rt(sc,mt)),
  put / ;
  if(tmg(mt), put 'Timing' else if(reo(mt), put 'Re-optimised' else put 'Dispatch' ) ) ;
  put @27 'PV%' ;
  loop(d,
    put / @26 (100 * GITdisc(d)):4:1 @30 ;
    loop(sc_sim(sc), put hvdcgrosstot_pv(sc,mt,d):12:1 ) ;
  ) ;
) ;

put /// 'Total HVDC charges - net of tax, $m (present value)' / @30 ; loop(sc_sim(sc), put sc.tl:>12 ) ;
loop(mt$sum(sc, sc_rt(sc,mt)),
  put / ;
  if(tmg(mt), put 'Timing' else if(reo(mt), put 'Re-optimised' else put 'Dispatch' ) ) ;
  put @27 'PV%' ;
  loop(d,
    put / @26 (100 * GITdisc(d)):4:1 @30 ;
    loop(sc_sim(sc), put hvdcnettot_pv(sc,mt,d):12:1 ) ;
  ) ;
) ;

put /// 'Total variable O&M expenses with LF adjustment - before deducting tax, $m (present value)' / @30 ;
loop(sc_sim(sc), put sc.tl:>12 ) ;
loop(mt$sum(sc, sc_rt(sc,mt)),
  put / ;
  if(tmg(mt), put 'Timing' else if(reo(mt), put 'Re-optimised' else put 'Dispatch' ) ) ;
  put @27 'PV%' ;
  loop((scenarios, d)$sum(sc, vopexgrosstot_pv(sc,mt,scenarios, d)),
    put / @14
    if(sameas(scenarios, 'dum'),
      put @26 (100 * GITdisc(d)):4:1 @30 ;
      else
      put scenarios.tl, (100 * i_scenarioWeight(sc,scenarios) ):6:2, (100 * GITdisc(d)):6:1 @30 ;
    ) ;
    loop(sc_sim(sc), put vopexgrosstot_pv(sc,mt,scenarios, d):12:1 ) ;
  ) ;
) ;

put /// 'Total variable O&M expenses with LF adjustment - net of tax, $m (present value)' / @30 ;
loop(sc_sim(sc), put sc.tl:>12 ) ;
loop(mt$sum(sc, sc_rt(sc,mt)),
  put / ;
  if(tmg(mt), put 'Timing' else if(reo(mt), put 'Re-optimised' else put 'Dispatch' ) ) ;
  put @27 'PV%' ;
  loop((scenarios, d)$sum(sc, vopexgrosstot_pv(sc,mt,scenarios, d)),
    put / @14
    if(sameas(scenarios, 'dum'),
      put @26 (100 * GITdisc(d)):4:1 @30 ;
      else
      put scenarios.tl, (100 * i_scenarioWeight(sc,scenarios) ):6:2, (100 * GITdisc(d)):6:1 @30 ;
    ) ;
    loop(sc_sim(sc), put vopexnettot_pv(sc,mt,scenarios, d):12:1 ) ;
  ) ;
) ;

put /// 'Total variable O&M expenses without LF adjustment - before deducting tax, $m (present value)' / @30 ;
loop(sc_sim(sc), put sc.tl:>12 ) ;
loop(mt$sum(sc, sc_rt(sc,mt)),
  put / ;
  if(tmg(mt), put 'Timing' else if(reo(mt), put 'Re-optimised' else put 'Dispatch' ) ) ;
  put @27 'PV%' ;
  loop((scenarios, d)$sum(sc, vopexgrosstot_pv(sc,mt,scenarios, d)),
    put / @14
    if(sameas(scenarios, 'dum'),
      put @26 (100 * GITdisc(d)):4:1 @30 ;
      else
      put scenarios.tl, (100 * i_scenarioWeight(sc,scenarios) ):6:2, (100 * GITdisc(d)):6:1 @30 ;
    ) ;
    loop(sc_sim(sc), put vopexgrosstotNoLF_pv(sc,mt,scenarios, d):12:1 ) ;
  ) ;
) ;

put /// 'Total variable O&M expenses without LF adjustment - net of tax, $m (present value)' / @29 ;
loop(sc_sim(sc), put sc.tl:>12 ) ;
loop(mt$sum(sc, sc_rt(sc,mt)),
  put / ;
  if(tmg(mt), put 'Timing' else if(reo(mt), put 'Re-optimised' else put 'Dispatch' ) ) ;
  put @27 'PV%' ;
  loop((scenarios, d)$sum(sc, vopexgrosstot_pv(sc,mt,scenarios, d)),
    put / @14
    if(sameas(scenarios, 'dum'),
      put @26 (100 * GITdisc(d)):4:1 @30 ;
      else
      put scenarios.tl, (100 * i_scenarioWeight(sc,scenarios) ):6:2, (100 * GITdisc(d)):6:1 @30 ;
    ) ;
    loop(sc_sim(sc), put vopexnettotNoLF_pv(sc,mt,scenarios, d):12:1 ) ;
  ) ;
) ;


**
** Yet to write out the 16 transmission capex related parameters... but do we even want to?
** txcapchrg_r(sc,mt,r,rr,ps,y)                 'Transmission capex charges (net of depreciation tax credit effects) by built equipment by year, $m (real)'
** txcapchrg_pv(sc,mt,r,rr,ps,y,d)              'Transmission capex charges (net of depreciation tax credit effects) by built equipment by year, $m (present value)'
** txcapchrgyr_r(sc,mt,y)                       'Transmission capex charges (net of depreciation tax credit effects) by year, $m (real)'
** txcapchrgyr_pv(sc,mt,y,d)                    'Transmission capex charges (net of depreciation tax credit effects) by year, $m (present value)'
** txcapchrgeqp_r(sc,mt,r,rr,ps)                'Transmission capex charges (net of depreciation tax credit effects) by equipment, $m (real)'
** txcapchrgeqp_pv(sc,mt,r,rr,ps,d)             'Transmission capex charges (net of depreciation tax credit effects) by equipment, $m (present value)'
** txcapchrgtot_r(sc,mt)                        'Total transmission capex charges (net of depreciation tax credit effects), $m (real)'
** txcapchrgtot_pv(sc,mt,d)                     'Total transmission capex charges (net of depreciation tax credit effects), $m (present value)'
** txtaxcred_r(sc,mt,r,rr,ps,y)                 'Tax credit on depreciation by built transmission equipment by year, $m (real)'
** txtaxcred_pv(sc,mt,r,rr,ps,y,d)              'Tax credit on depreciation by built transmission equipment by year, $m (present value)'
** txtaxcredyr_r(sc,mt,y)                       'Tax credit on depreciation on transmission equipment by year, $m (real)'
** txtaxcredyr_pv(sc,mt,y,d)                    'Tax credit on depreciation on transmission equipment by year, $m (present value)'
** txtaxcredeqp_r(sc,mt,r,rr,ps)                'Tax credit on depreciation by transmission equipment, $m (real)'
** txtaxcredeqp_pv(sc,mt,r,rr,ps,d)             'Tax credit on depreciation by transmission equipment, $m (present value)'
** txtaxcredtot_r(sc,mt)                        'Total tax credit on depreciation of transmission equipment, $m (real)'
** txtaxcredtot_pv(sc,mt,d)                     'Total tax credit on depreciation of transmission equipment, $m (present value)'   ;
**



*===============================================================================================
* 5. Write out the generation and transmission investment schedules in various formats.

* Done already



*===============================================================================================
* 6. Write out various summaries of the MW installed net of retirements.

Parameters
  TechIldMW(sc,k,ild)  'Built megawatts less retired megawatts by technology and island'
  TechZoneMW(sc,k,e)   'Built megawatts less retired megawatts by technology and zone'
  TechRegMW(sc,k,r)    'Built megawatts less retired megawatts by technology and region'
  TechYearMW(sc,k,y)   'Built megawatts less retired megawatts by technology and year'
  SCyearMW(sc,y)       'Built megawatts less retired megawatts by SC and year'
  ;

if(%RunType%=2,
  TechIldMW(sc,k,ild) = sum((dis(mt),mapg_k(g,k),mapg_ild(g,ild),y), s2_build(sc,mt,g,y) - s2_retire(sc,mt,g,y) - exogMWretired(sc,g,y)) ;
  TechZoneMW(sc,k,e)  = sum((dis(mt),mapg_k(g,k),mapg_e(g,e),y),     s2_build(sc,mt,g,y) - s2_retire(sc,mt,g,y) - exogMWretired(sc,g,y)) ;
  TechRegMW(sc,k,r)   = sum((dis(mt),mapg_k(g,k),mapg_r(g,r),y),     s2_build(sc,mt,g,y) - s2_retire(sc,mt,g,y) - exogMWretired(sc,g,y)) ;
  TechYearMW(sc,k,y)  = sum((dis(mt),mapg_k(g,k)),                   s2_build(sc,mt,g,y) - s2_retire(sc,mt,g,y) - exogMWretired(sc,g,y)) ;
  else
  if(%SuppressReopt%=1,
    TechIldMW(sc,k,ild) = sum((tmg(mt),mapg_k(g,k),mapg_ild(g,ild),y), s2_build(sc,mt,g,y) - s2_retire(sc,mt,g,y) - exogMWretired(sc,g,y)) ;
    TechZoneMW(sc,k,e)  = sum((tmg(mt),mapg_k(g,k),mapg_e(g,e),y),     s2_build(sc,mt,g,y) - s2_retire(sc,mt,g,y) - exogMWretired(sc,g,y)) ;
    TechRegMW(sc,k,r)   = sum((tmg(mt),mapg_k(g,k),mapg_r(g,r),y),     s2_build(sc,mt,g,y) - s2_retire(sc,mt,g,y) - exogMWretired(sc,g,y)) ;
    TechYearMW(sc,k,y)  = sum((tmg(mt),mapg_k(g,k)),                   s2_build(sc,mt,g,y) - s2_retire(sc,mt,g,y) - exogMWretired(sc,g,y)) ;
    else
    TechIldMW(sc,k,ild) = sum((reo(mt),mapg_k(g,k),mapg_ild(g,ild),y), s2_build(sc,mt,g,y) - s2_retire(sc,mt,g,y) - exogMWretired(sc,g,y)) ;
    TechZoneMW(sc,k,e)  = sum((reo(mt),mapg_k(g,k),mapg_e(g,e),y),     s2_build(sc,mt,g,y) - s2_retire(sc,mt,g,y) - exogMWretired(sc,g,y)) ;
    TechRegMW(sc,k,r)   = sum((reo(mt),mapg_k(g,k),mapg_r(g,r),y),     s2_build(sc,mt,g,y) - s2_retire(sc,mt,g,y) - exogMWretired(sc,g,y)) ;
    TechYearMW(sc,k,y)  = sum((reo(mt),mapg_k(g,k)),                   s2_build(sc,mt,g,y) - s2_retire(sc,mt,g,y) - exogMWretired(sc,g,y)) ;
  ) ;
) ;

SCyearMW(sc,y) = sum(k, TechYearMW(sc,k,y)) ;

put bldsum 'Various summaries of newly installed generation plant net of retirements, MW' / ;

put // 'Installed less retired MW by technology and island'
loop(sc_sim(sc)$sum((k,ild), TechIldMW(sc,k,ild)),
  put // sc.tl, ': ', sc.te(sc) @58 ; loop(ild, put ild.tl:>15 ) ; put '          Total' ;
  loop(k$sum(ild, TechIldMW(sc,k,ild)),
    put / @3 k.te(k) @58 ; loop(ild, put TechIldMW(sc,k,ild):15:1 ) ; put (sum(ild, TechIldMW(sc,k,ild))):15:1 ;
  ) ;
  put / @3 'Total' @58 ; loop(ild, put (sum(k, TechIldMW(sc,k,ild))):15:1 ) ; put (sum((k,ild), TechIldMW(sc,k,ild))):15:1 ;
) ;

put // 'Installed less retired MW by technology and zone'
loop(sc_sim(sc)$sum((k,e), TechZoneMW(sc,k,e)),
  put // sc.tl, ': ', sc.te(sc) @58 ; loop(e, put e.tl:>15 ) ; put '          Total' ;
  loop(k$sum(e, TechZoneMW(sc,k,e)),
    put / @3 k.te(k) @58 ; loop(e, put TechZoneMW(sc,k,e):15:1 ) ; put (sum(e, TechZoneMW(sc,k,e))):15:1 ;
  ) ;
  put / @3 'Total' @58 ; loop(e, put (sum(k, TechZoneMW(sc,k,e))):15:1 ) ; put (sum((k,e), TechZoneMW(sc,k,e))):15:1 ;
) ;

put /// 'Installed less retired MW by technology and region'
loop(sc_sim(sc)$sum((k,r), TechRegMW(sc,k,r)),
  put // sc.tl, ': ', sc.te(sc) @58 ; loop(r, put r.tl:>15 ) ; put '          Total' ;
  loop(k$sum(r, TechRegMW(sc,k,r)),
    put / @3 k.te(k) @58 ; loop(r, put TechRegMW(sc,k,r):15:1 ) ; put (sum(r, TechRegMW(sc,k,r))):15:1 ;
  ) ;
  put / @3 'Total' @58 ; loop(r, put (sum(k, TechRegMW(sc,k,r))):15:1 ) ; put (sum((k,r), TechRegMW(sc,k,r))):15:1 ;
) ;

put /// 'Installed less retired MW by technology and year'
loop(sc_sim(sc)$sum((k,y), TechYearMW(sc,k,y)),
  put // sc.tl, ': ', sc.te(sc) @58 ; loop(y, put y.tl:>8 ) ; put '    Total' ;
  loop(k$sum(y, TechYearMW(sc,k,y)),
    put / @3 k.te(k) @58 ; loop(y, put TechYearMW(sc,k,y):8:1 ) ; put (sum(y, TechYearMW(sc,k,y))):9:1 ;
  ) ;
  put / @3 'Total' @58 ; loop(y, put (sum(k, TechYearMW(sc,k,y))):8:1 ) ;
) ;

put /// 'Installed less retired MW by SC and year' / @58 ; loop(y, put y.tl:>8 ) ; put '    Total' ;
loop(sc_sim(sc), put / @3 sc.te(sc) @58 ; loop(y, put SCyearMW(sc,y):8:1 ) ; put (sum(y, SCyearMW(sc,y))):9:1 ) ;

put /// 'Zone descriptions' ;
loop(e, put / e.tl @15 e.te(e) ) ;

put /// 'Region descriptions' ;
loop(r, put / r.tl @15 r.te(r) ) ;

put /// 'SC descriptions' ;
loop(sc_sim(sc), put / sc.tl @15 sc.te(sc) ) ;



*===============================================================================================
* 7. Write out various summaries of activity associated with peaking plant.

* Figure out which peakers produce more than 20% energy in any year.
counter = 0 ;
loop((activeMTOC(sc,mt,scenarios) ,mapg_k(g,k))$( peaker(k) * sum(y$activeCapacity(sc,g,y), 1) ),
  loop(y$( counter < 0.2 ),
    counter = genYr(sc,mt,scenarios, g,y) / (1e-3 * i_nameplate(sc,g) * sum((t,lb), maxcapfact(g,t,lb) * hoursPerBlock(t,lb)) ) ;
    pkrs_plus20(sc,mt,scenarios, g)$( counter >= 0.2 ) = yes ;
  ) ;
  counter = 0 ;
) ;

* Figure out which non-peakers produce less than 20% energy in any year.
counter = 1 ;
loop((activeMTOC(sc,mt,scenarios) ,mapg_k(g,k))$( not peaker(k) ),
  loop(y$( counter > 0.2 ),
    counter$( i_nameplate(sc,g) * sum((t,lb), maxcapfact(g,t,lb) * hoursPerBlock(t,lb)) ) =
      genYr(sc,mt,scenarios, g,y) / (1e-3 * i_nameplate(sc,g) * sum((t,lb), maxcapfact(g,t,lb) * hoursPerBlock(t,lb)) ) ;
    nopkr_minus20(sc,mt,scenarios, g)$( counter > 0 and counter <= 0.2 ) = yes ;
  ) ;
  counter = 1 ;
) ;

put pksum 'Peaking plant and VOLL activity' / 'Run name:', '%OutPrefix%' /
 'First modelled year:', '%FirstYr%' /
 'Number of modelled years:', numyears:2:0  /
 'Technologies specified by user to be peaking:' loop(peaker(k), put k.tl ) ;

put /// 'Peaking capacity by technology, MW' / 'Technology' '' loop(sc_sim(sc), put sc.tl ) ;
loop(peaker(k),
  put / k.te(k) ;
  put 'Existing capacity'              loop(sc_sim(sc), put sum(mapg_k(g,k), initCap(g)) ) ; 
  put / '' 'Capacity able to be built' loop(sc_sim(sc), put potentialCap(sc,k,'blt') ) ; 
  put / '' 'Capacity actually built'   loop(sc_sim(sc), put sum(buildSoln(mt), actualCap(sc,mt,k,'blt')) ) ; 
) ;

put /// 'Peaking capacity installed by region, MW' / 'Region' loop(sc_sim(sc), put sc.tl ) ;
loop(r,
  put / r.te(r) ; loop(sc_sim(sc), put sum((g,k)$( peaker(k) * mapg_k(g,k) * mapg_r(g,r) ), buildMW(sc,g)) ) ;
) ;

put /// 'Peaking capacity installed by zone, MW' / 'Zone' loop(sc_sim(sc), put sc.tl ) ;
loop(e,
  put / e.te(e) ; loop(sc_sim(sc), put sum((g,k)$( peaker(k) * mapg_k(g,k) * mapg_e(g,e) ), buildMW(sc,g)) ) ;
) ;

put /// 'Peakers exceeding 20% utilisation in any year' / 'Plant' 'Run type' 'Scenario' loop(sc_sim(sc), put sc.tl ) ;
loop((g,mt,scenarios) $sum(sc, pkrs_plus20(sc,mt,scenarios, g)),
  put / g.te(g), mt.tl, scenarios.tl ;
  loop(sc_sim(sc),
    if(pkrs_plus20(sc,mt,scenarios, g), put 'y' else put '' ) ;
  ) ;
) ;

put /// 'Non-peakers at less than 20% utilisation in any year' / 'Plant' 'Run type' 'Scenario' loop(sc_sim(sc), put sc.tl ) ;
loop((g,mt,scenarios) $sum(sc, nopkr_minus20(sc,mt,scenarios, g)),
  put / g.te(g), mt.tl, scenarios.tl ;
  loop(sc_sim(sc),
    if(nopkr_minus20(sc,mt,scenarios, g), put 'y' else put '' ) ;
  ) ;
) ;

put /// 'Energy produced by peakers, GWh' / 'SC' 'Run type' 'Scenario' 'Plant' 'Tech' 'Substn' 'MaxPotGWh' loop(y, put y.tl ) ; put '' 'Technology' ;
loop((activeMTOC(sc,mt,scenarios) ,g,peaker(k),i)$( mapg_k(g,k) * mapg_i(g,i) * sum(y$activeCapacity(sc,g,y), 1) ),
  put / sc.tl, mt.tl, scenarios.tl, g.te(g), k.tl, i.tl, (1e-3 * i_nameplate(sc,g) * sum((t,lb), maxcapfact(g,t,lb) * hoursPerBlock(t,lb)) )
  loop(y, put genYr(sc,mt,scenarios, g,y) ) ;
  put k.te(k) ;
) ;

put /// 'Energy produced by peakers as a proportion of potential' / 'SC' 'Run type' 'Scenario' 'Plant' 'Tech' 'Substn' 'MaxPotGWh' loop(y, put y.tl ) ; put '' 'Technology' ;
loop((activeMTOC(sc,mt,scenarios) ,g,peaker(k),i)$( mapg_k(g,k) * mapg_i(g,i) * sum(y$activeCapacity(sc,g,y), 1) ),
  put / sc.tl, mt.tl, scenarios.tl, g.te(g), k.tl, i.tl, (1e-3 * i_nameplate(sc,g) * sum((t,lb), maxcapfact(g,t,lb) * hoursPerBlock(t,lb)) )
  loop(y, put ( genYr(sc,mt,scenarios, g,y) / (1e-3 * i_nameplate(sc,g) * sum((t,lb), maxcapfact(g,t,lb) * hoursPerBlock(t,lb)) ) )  ) ;
  put k.te(k) ;
) ;

put /// 'VOLL by load block, period and year, GWh' / 'SC' 'Run type' 'Scenario' 'Plant' 'Period' 'Load block' loop(y, put y.tl ) ;
loop((activeMTOC(sc,mt,scenarios) ,s,t,lb)$sum(y$s2_vollgen(sc,mt,s,y,t,lb,scenarios) , 1),
  put / sc.tl, mt.tl, scenarios.tl, s.te(s), t.tl, lb.tl ;
  loop(y, put s2_vollgen(sc,mt,s,y,t,lb,scenarios)  ) ;
) ;

put /// 'Energy produced by peakers by load block, period and year, GWh' / 'SC' 'Run type' 'Scenario' 'Plant' 'Period' 'Load block' loop(y, put y.tl ) ;
loop((activeMTOC(sc,mt,scenarios) ,g,peaker(k),t,lb)$( mapg_k(g,k) * sum(y$s2_gen(sc,mt,g,y,t,lb,scenarios) , 1) ),
  put / sc.tl, mt.tl, scenarios.tl, g.te(g), t.tl, lb.tl ;
  loop(y, put s2_gen(sc,mt,g,y,t,lb,scenarios)  ) ;
) ;

*Display pkrs_plus20, nopkr_minus20 ;



*===============================================================================================
* 8. Write out the GIT summary results.

gityrs(y)$( yearNum(sc,y) <  begtermyrs ) = yes ;
trmyrs(y)$( yearNum(sc,y) >= begtermyrs ) = yes ;
mapcy_y(git,gityrs) = yes ;
mapcy_y(trm,trmyrs) = yes ;

GITresults('itm1',gitd,sc_sim(sc),dt,cy) = sum((dis(mt),g,mapcy_y(cy,y),firstPeriod(t)), PVfacs(y,t,gitd,dt) * ( capchrg_r(sc,mt,g,y) + taxcred_r(sc,mt,g,y)) ) ;

GITresults('itm2',gitd,sc_sim(sc),dt,cy) = sum((dis(mt),g,mapcy_y(cy,y),t), PVfacs(y,t,gitd,dt) * fopexgross_r(sc,mt,g,y,t) ) ;

GITresults('itm3',gitd,sc_sim(sc),dt,cy) = sum((dis(mt),g,mapcy_y(cy,y),t), PVfacs(y,t,gitd,dt) * hvdcgross_r(sc,mt,g,y,t) ) ;

GITresults('itm4',gitd,sc_sim(sc),dt,cy) = sum((dis(mt),g,mapcy_y(cy,y),t,scenarios) , PVfacs(y,t,gitd,dt) * ( 1 / numhd ) * vopexgrossnolf_r(sc,mt,g,y,t,scenarios)  ) ;

GITresults('itm5',gitd,sc_sim(sc),dt,cy) = sum((dis(mt),g,mapcy_y(cy,y),firstPeriod(t)), PVfacs(y,t,gitd,dt) * capchrg_r(sc,mt,g,y) ) ;

GITresults('itm6',gitd,sc_sim(sc),dt,cy) = sum((dis(mt),g,mapcy_y(cy,y),t), PVfacs(y,t,gitd,dt) * ( 1 - i_taxRate ) * fopexgross_r(sc,mt,g,y,t) ) ;

GITresults('itm7',gitd,sc_sim(sc),dt,cy) = sum((dis(mt),g,mapcy_y(cy,y),t), PVfacs(y,t,gitd,dt) * ( 1 - i_taxRate ) * hvdcgross_r(sc,mt,g,y,t) ) ;

GITresults('itm8',gitd,sc_sim(sc),dt,cy) = sum((dis(mt),g,mapcy_y(cy,y),t,scenarios) , PVfacs(y,t,gitd,dt) * ( 1 / numhd ) * ( 1 - i_taxRate ) * vopexgrossnolf_r(sc,mt,g,y,t,scenarios)  ) ;

GITresults('itm9',gitd,sc_sim(sc),dt,cy) = sum((dis(mt),allowedStates(sc,r,rr,ps),mapcy_y(cy,y),firstPeriod(t)), PVfacs(y,t,gitd,dt) * ( txcapchrg_r(sc,mt,allowedStates(sc,r,rr,ps),y) + txtaxcred_r(sc,mt,allowedStates(sc,r,rr,ps),y)) ) ;

GITresults('itm10',gitd,sc_sim(sc),dt,cy) = sum((dis(mt),allowedStates(sc,r,rr,ps),mapcy_y(cy,y),firstPeriod(t)), PVfacs(y,t,gitd,dt) * txcapchrg_r(sc,mt,allowedStates(sc,r,rr,ps),y) ) ;

GITresults('itmA',gitd,sc_sim(sc),dt,cy) = GITresults('itm1',gitd,sc,dt,cy) + GITresults('itm2',gitd,sc,dt,cy) + GITresults('itm3',gitd,sc,dt,cy) ;

GITresults('itmB',gitd,sc_sim(sc),dt,cy) = GITresults('itm4',gitd,sc,dt,cy) ;

GITresults('itmC',gitd,sc_sim(sc),dt,cy) = GITresults('itm9',gitd,sc,dt,cy) ;

GITresults('itmD',gitd,sc_sim(sc),dt,cy) = GITresults('itm1',gitd,sc,dt,'trm') + GITresults('itm2',gitd,sc,dt,'trm') + GITresults('itm3',gitd,sc,dt,'trm') + GITresults('itm4',gitd,sc,dt,'trm') ;
 
GITresults('itmE',gitd,sc_sim(sc),dt,cy) = GITresults('itmA',gitd,sc,dt,cy) + GITresults('itmB',gitd,sc,dt,cy) - GITresults('itmC',gitd,sc,dt,cy) + GITresults('itmD',gitd,sc,dt,cy) ;

*Display cy, item, git, trm, mapcy_y, gityrs, trmyrs, GITresults ;

put gits
  'GIT analysis' /
  'Run name:', '%OutPrefix%' /
  'All results in millions of %FirstYr% dollars' /
  'All results are averages over the hydro sequences simulated (i.e. model DISP)' /
  'Number of inflow sequences simulated:' ;
loop(sc_sim(sc), put / '', sc.tl, numdisyrs(sc):0 ) ;

put // 'Summary GIT results - mid-period discounting (absolute, not change from base)', 'Discount rate' ;
loop(sc_sim(sc), put sc.tl ) ;
loop(item$( ord(item) > 10 ),
  put / item.te(item) ;
  counter = 0 ;
  loop(gitd(d),
    counter = counter + 1 ;
    if(counter = 1, put d.te(d) else put / '', d.te(d) ) ;
    loop(sc_sim(sc), put GITresults(item,gitd,sc,'mid','git') ) ;
  ) ;
) ;

put /// 'Summary GIT results - end-of-year discounting (absolute, not change from base)', 'Discount rate' ;
loop(sc_sim(sc), put sc.tl ) ;
loop(item$( ord(item) > 10 ),
  put / item.te(item) ;
  counter = 0 ;
  loop(gitd(d),
    counter = counter + 1 ;
    if(counter = 1, put d.te(d) else put / '', d.te(d) ) ;
    loop(sc_sim(sc), put GITresults(item,gitd,sc,'eoy','git') ) ;
  ) ;
) ;

put /// 'Components of GIT analysis - mid-period discounting', 'Discount rate' ;
loop(sc_sim(sc), put sc.tl ) ;
loop(item$( ord(item) < 11 ),
  put / item.te(item) ;
  counter = 0 ;
  loop(gitd(d),
    counter = counter + 1 ;
    if(counter = 1, put d.te(d) else put / '', d.te(d) ) ;
    loop(sc_sim(sc), put GITresults(item,gitd,sc,'mid','git') ) ;
  ) ;
) ;

put /// 'Components of GIT analysis - end-of-year discounting', 'Discount rate' ;
loop(sc_sim(sc), put sc.tl ) ;
loop(item$( ord(item) < 11 ),
  put / item.te(item) ;
  counter = 0 ;
  loop(gitd(d),
    counter = counter + 1 ;
    if(counter = 1, put d.te(d) else put / '', d.te(d) ) ;
    loop(sc_sim(sc), put GITresults(item,gitd,sc,'eoy','git') ) ;
  ) ;
) ;



*===============================================================================================
* 9. Write a report of HVDC charges sliced and diced all different ways.

put HVDCsum 'HVDC charges by year - before deducting tax, $m (real)' / 'SC' ; loop(y, put y.tl ) ;
loop((buildSoln(mt),sc_sim(sc))$sum((g,y,t), hvdcgross_r(sc,mt,g,y,t)),
  put / sc.tl ;
  loop(y, put ( sum((g,t), hvdcgross_r(sc,mt,g,y,t)) ) ) ;
) ;

put /// 'HVDC charges by year - after deducting tax, $m (real)' / 'SC' ; loop(y, put y.tl ) ;
loop((buildSoln(mt),sc_sim(sc))$sum((g,y,t), hvdcnet_r(sc,mt,g,y,t)),
  put / sc.tl ;
  loop(y, put ( sum((g,t), hvdcnet_r(sc,mt,g,y,t)) ) ) ;
) ;

put /// 'HVDC charges by plant - before deducting tax, $m (real)' / 'Plant' 'Tech' 'Fuel' 'Region' 'Zone' 'Owner' 'Share' 'Nameplate' ;
loop(sc_sim(sc), put sc.tl ) ;
loop((buildSoln(mt),g,k,f,r,e,o)$( mapg_k(g,k) * mapg_f(g,f) * mapg_r(g,r) * mapg_e(g,e) * mapg_o(g,o) * sum((sc,y,t), hvdcgross_r(sc,mt,g,y,t)) ),
  put / g.tl, k.tl, f.tl, r.tl, e.tl, o.tl, HVDCshr(o), i_nameplate(sc,g) ;
  loop(sc_sim(sc), put ( sum((y,t), hvdcgross_r(sc,mt,g,y,t)) ) ) ;
) ;

put /// 'HVDC charges by plant - after deducting tax, $m (real)' / 'Plant' 'Tech' 'Fuel' 'Region' 'Zone' 'Owner' 'Share' 'Nameplate' ;
loop(sc_sim(sc), put sc.tl ) ;
loop((buildSoln(mt),g,k,f,r,e,o)$( mapg_k(g,k) * mapg_f(g,f) * mapg_r(g,r) * mapg_e(g,e) * mapg_o(g,o) * sum((sc,y,t), hvdcnet_r(sc,mt,g,y,t)) ),
  put / g.tl, k.tl, f.tl, r.tl, e.tl, o.tl, HVDCshr(o), i_nameplate(sc,g) ;
  loop(sc_sim(sc), put ( sum((y,t), hvdcnet_r(sc,mt,g,y,t)) ) ) ;
) ;



$ontext
This chunk of code needs to be finished, i.e. it is to see if the revenue collected from HVDC charges is sufficient, and if it ain't,
you can reset the level of $/kw charge in the input data. 

Parameter ImpliedHVDC(sc,y) 'Implied HVDC charge, $/kW' ;
ImpliedHVDC(sc,y)$sum((buildSoln(mt),g)$( sigen(g) * posbuildm(g,sc) ), s2_capacity(sc,mt,g,y)) =
  sum((buildSoln(mt),g,t), hvdcgross_r(sc,mt,g,y,t)) / sum((buildSoln(mt),k,g)$(( not demandGen(sc,k) ) * sigen(g) * posbuildm(g,sc) * mapg_k(g,k)), s2_capacity(sc,mt,g,y)) ;

Display ImpliedHVDC, i_HVDCrevenue ;

*put /// 'Implied HVDC charges by plant, $/kW (real)' / 'Plant' 'Tech' 'Fuel' 'Region' 'Zone' 'Owner' 'Share' 'Nameplate' ;
*loop(sc_sim(sc), put sc.tl ) ;
*loop((g,k,f,r,e,o)$( mapg_k(g,k) * mapg_f(g,f) * mapg_r(g,r) * mapg_e(g,e) * mapg_o(g,o) * sum((sc,y,t), ImpliedHVDC(sc,g,y,t)) ),
*  put / g.tl, k.tl, f.tl, r.tl, e.tl, o.tl, HVDCshr(o), i_nameplate(sc,g) ;
*  loop(sc_sim(sc), put ( sum((y,t), ImpliedHVDC(sc,g,y,t)) ) ) ;
*) ;


* NB: The HVDC charge applies only to committed and new SI projects.
  1e-6 * sum((y,t), PVfacG(y,t) * (1 - i_taxRate) * (
           ( 1/card(t) ) * (
           sum((g,k,o)$((not demandGen(sc,k)) * sigen(g) * posbuild(g) * mapg_k(g,k) * mapg_o(g,o)), HVDCshr(o) * HVDCcharge(y) * CAPACITY(g,y))
           )
         ) )

* Generation plant HVDC costs
  hvdcgross_r(sc,mt,g,y,t) =  1e-6 *
    ( 1/card(t) ) * sum((k,o)$( ( not demandGen(sc,k) ) * sigen(g) * posbuildm(g,sc) * mapg_k(g,k) * mapg_o(g,o) ), HVDCshr(o) * HVDCchargem(y,sc) * s2_capacity(sc,mt,g,y)) ;
  hvdcgross_pv(sc,mt,g,y,t,d) = PVfacsM(y,t,d) * hvdcgross_r(sc,mt,g,y,t) ;
  hvdcnet_r(sc,mt,g,y,t)      = (1 - i_taxRate)  * hvdcgross_r(sc,mt,g,y,t) ;
  hvdcnet_pv(sc,mt,g,y,t,d)   = PVfacsM(y,t,d) * hvdcnet_r(sc,mt,g,y,t) ;
HVDCchargem(y,sc) = 1e3 * i_HVDCcharge(y,sc) ;
$offtext





*===============================================================================================
* 10. Write a report of features common to all scenarios.

* Skip this entire section if numSC = 1.
if(NumSC > 1,

* Figure out the number of combinations - used in counting all SC pairs where build year is within 5 years.
  numSC_fact = numSC ;      counter = numSC_fact ;
  numSC_fact2 = numSC - 2 ; counter2 = numSC_fact2 ;
  loop(sc_sim(sc),
    if(counter > 1,  numSC_fact  = numSC_fact *  ( counter - 1 ) ) ;
    if(counter2 > 1, numSC_fact2 = numSC_fact2 * ( counter2 - 1 ) ) ;
    counter =  counter  - 1 ;
    counter2 = counter2 - 1 ;
  ) ;

* numCombos equals 1 if numSC = 2, otherwise it equals numSC - 2 
  numCombos = 1 ;
  numCombos$( numSC > 2 ) = numSC_fact / ( 2 * numSC_fact2 ) ;

* Figure out which plants get built in all scenarios.
  buildall(g)$( ( sum(sc_sim(sc), buildYr(sc,g)) >= numSC * firstyear ) and
                ( sum(sc_sim(sc), buildYr(sc,g)) <= numSC * lastyear ) ) = yes ;

* Of the plants built in all scenarios, identify which ones get built in the same year.
  loop(sc_sim(sc),
    buildall_sameyr(buildall(g))$( sum(scs, buildYr(scs,g)) = numSC * buildYr(sc,g) ) = yes ;
  ) ;

* Of the plants built in all scenarios, identify which ones don't get built in the same year.
  buildall_notsameyr(buildall(g))$( not buildall_sameyr(g) ) = yes ; 

* Of the plants built in all scenarios but not all in the same year, identify those that get built within 5 years of each other.
  loop((g,sc,scs)$( buildall_notsameyr(g) * sc_sim(sc) * sc_sim(scs) * ( ord(sc) > ord(scs) ) ),
    build_close5(g,sc,scs)$( ( buildYr(sc,g) - buildYr(scs,g) > -6 ) and ( buildYr(sc,g) - buildYr(scs,g) < 6 ) ) = yes ;
  ) ;
  buildclose5(buildall_notsameyr(g))$( sum((sc,scs)$build_close5(g,sc,scs), 1 ) = numCombos ) = yes ;

* Of the plants built in all scenarios but not all in the same year, identify those that get built within 5 years of each other.
  buildplus5(buildall_notsameyr(g))$( not buildclose5(g) ) = yes ;

* Figure out retirements, refurbishments and transmission upgrades that happen in exactly the same year in each sc.
  loop(buildSoln(mt),
    retiresame(sc,g,y)$( sum(scs, s2_retire(scs,mt,g,y) + exogMWretired(scc,g,y)) = numSC * ( s2_retire(sc,mt,g,y) + exogMWretired(sc,g,y)) ) = s2_retire(sc,mt,g,y) + exogMWretired(sc,g,y) ;
    refurbsame(sc,g)$( sum(scs, s2_isretired(scs,mt,g)) = numSC ) = i_refurbDecisionYear(sc,g) ;
    txupgradesame(sc,tupg,y)$( sum(scs, s2_txprojvar(scs,mt,tupg,y)) = numSC ) = yearNum(sc,y) ;
  ) ;

  Display numSC_fact, numSC_fact2, numCombos, buildall, buildall_sameyr, buildall_notsameyr, buildclose5, buildplus5, retiresame, refurbsame, txupgradesame ;

* Write common features report.
  put common 'Common features across all scenarios' /// 'Scenarios in this model run: ' loop(sc_sim(sc), put sc.tl ', ' ) ;
  put /  'NB: Build year refers to the year the first increment of plant is built in case of builds over multiple years.' / ;

  put // 'Year and MW for all plant built in the same year in all scenarios' / 'Plant' @18 'Year' @23 ; loop(sc_sim(sc), put sc.tl:>6 ) ;
  loop((y,buildall_sameyr(g))$( numSC * yearNum(sc,y) = sum(sc_sim(sc), buildYr(sc,g)) ),
    put / g.tl @18 y.tl @23 loop(sc_sim(sc), put buildMW(sc,g):>6:0 ) ;
  ) ;

  put // 'MW and year built for all plant built in all scenarios, not in same year, but within 5 years of each other' /
         'Plant' @23 loop(sc_sim(sc), put sc.tl:>6 ) put '      ' loop(sc_sim(sc), put sc.tl:>6 ) ;
  if(sum(buildclose5(g), 1) > 0,
    loop(buildclose5(g),
      put / g.tl @23 loop(sc_sim(sc), put buildMW(sc,g):>6:0 ) put '      ' loop(sc_sim(sc), put buildYr(sc,g):>6:0 ) ;
    ) ;
    else put / 'There are none' ) ;

  put // 'MW and year built for all plant built in all scenarios, not in same year, but more than 5 years apart' /
         'Plant' @23 loop(sc_sim(sc), put sc.tl:>6 ) put '      ' loop(sc_sim(sc), put sc.tl:>6 ) ;
  if(sum(buildplus5(g), 1) > 0,
    loop(buildplus5(g),
      put / g.tl @23 loop(sc_sim(sc), put buildMW(sc,g):>6:0 ) put '      ' loop(sc_sim(sc), put buildYr(sc,g):>6:0 ) ;
    ) ;
    else put / 'There are none' ) ;

  put // 'MW retired' / 'Year' @7 'Plant' @23 ; loop(sc_sim(sc), put sc.tl:>6 ) ;
  if(sum((sc,g,y)$retiresame(sc,g,y), 1) > 0,
    loop((y,g)$sum(sc_sim(sc), retiresame(sc,g,y)),
      put / y.tl @7 g.tl @23 loop(sc_sim(sc), put retiresame(sc,g,y):>6:0 ) ;
    ) ;
    else put / 'There are none' ) ;

  put // 'Plant for which the refurbishment decision year is the same in all scenarios' / 'Plant' @23 ; loop(sc_sim(sc), put sc.tl:>6 ) ;
  if(sum((sc,g)$refurbsame(sc,g), 1) > 0,
    loop(g$sum(sc_sim(sc), refurbsame(sc,g)),
      put / g.tl @23 loop(sc_sim(sc), put refurbsame(sc,g):>6:0 )
    ) ;
    else put / 'There are none' ) ;

  put // 'Transmission upgrade year' / 'Year' @7 'Upgrade' @23 ; loop(sc_sim(sc), put sc.tl:>6 ) ;
  if(sum((sc,tupg,y)$txupgradesame(sc,tupg,y), 1) > 0,
    loop((y,tupg)$sum(sc_sim(sc), txupgradesame(sc,tupg,y)),
      put / y.tl @7 tupg.tl @23 ;
      loop(sc_sim(sc), put txupgradesame(sc,tupg,y):>6:0 )
    ) ;
    else put / 'There are none' ) ;

  put // 'Build years for all plant not built in all scenarios' / 'Plant' @23 loop(sc_sim(sc), put sc.tl:>6 ) ;
  loop(noexist(sc,g)$( not buildall(g) and sum(sc$buildYr(sc,g), 1) > 0 ),
    put / g.tl @23 loop(sc_sim(sc), put buildYr(sc,g):>6:0 )
  ) ;

) ;



*===============================================================================================
* 11. Write out a file of miscellaneous scalars - to pass to Matlab.
*     NB: It is not necessary to put every scalar known to GEM in this file.

Put miscs ;
put 'LossValue|%LossValue%|A user-specified value of the LRMC of generation plant' / ;
put 'partGenBld|', partGenBld:2:0, '|1 to enable some new plants to be partially and/or incrementally built; 0 otherwise' / ;
put 'annMW|', annMW:5:0, '|Annual MW upper bound on aggregate new generation plant builds' / ;
put 'i_taxRate|', i_taxRate:5:3, '|Corporate tax rate' / ;
put 'penaltyViolateRenNrg|', penaltyViolateRenNrg:5:3, '|Penalty used to make renewable energy constraint feasible, $m/GWh' / ;
put 'security|', security:2:0, '|Switch to control usage of (N, N-1, N-2) security constraints' / ;
put 'useresv|',  useresv:2:0, '|Global reserve formulation activation flag (1 = use reserves, 0 = no reserves are modelled)' / ;



*===============================================================================================
* 12. Write out the mapping of inflow years to modelled years.

put HydYrs 'SC', 'Run Type', 'hY' loop(y, put y.tl ) ;
loop((sc,mt,hY)$( sum(y, s_inflowyr(sc,mt,hY,y)) ),
  put / sc.tl, mt.tl, hY.tl ;
  loop(y,
    if(ahy(hY), put 'Average' else put s_inflowyr(sc,mt,hY,y) ) ;
  ) ;
) ;



*===============================================================================================
* 13. Collect national generation, transmission, losses and load (GWh) into a single parameter.

chktotals(sc_rt(sc,mt),'Gen')  = sum((r,g,y,t,lb,scenarios) $( activeMTOC(sc,mt,scenarios)  and mapg_r(g,r) ), s2_gen(sc,mt,g,y,t,lb,scenarios) ) ;
chktotals(sc_rt(sc,mt),'Tx')   = sum((r,rr,y,t,lb,scenarios) $activeMTOC(sc,mt,scenarios) , hoursPerBlock(t,lb) * 1e-3 * s2_tx(sc,mt,r,rr,y,t,lb,scenarios) ) ;
chktotals(sc_rt(sc,mt),'Loss') = sum((r,rr,y,t,lb,scenarios) $activeMTOC(sc,mt,scenarios) , hoursPerBlock(t,lb) * 1e-3 * s2_loss(sc,mt,r,rr,y,t,lb,scenarios) ) ;
chktotals(sc_rt(sc,mt),'Dem')  =
  sum((r,t,lb,y,scenarios) $activeMTOC(sc,mt,scenarios) , ldcMWm(sc,r,t,lb,y) * hoursPerBlock(t,lb) * 1e-3 + sum(g$( mapg_r(g,r) * pdhydro(g) ), s2_pumpedgen(sc,mt,g,y,t,lb,scenarios) ) ) ;

chktotals(sc,mt,'Bal')$sc_rt(sc,mt) = chktotals(sc,mt,'Gen') - chktotals(sc,mt,'Dem') - chktotals(sc,mt,'Loss') ;

Display chktotals ;





*===============================================================================================
* 15. Report the presence of penalty or slack (i.e. violation) variables (if any).

slacks = 0 ;
slacks = sum((sc_rt,slk), objComponents(sc_rt,slk)) + sum((sc_rt,pen), objComponents(sc_rt,pen)) ; 

Option slacks:0 ; Display slacks ;

if(slacks > 0,

  Display 'Slack or penalty variables have been used in at least one solution', %List_10_s3slacks%, s2_renNrgPenalty, s2_resvviol ;
  Execute_Unload '%OutPath%\%Outprefix%\GDX\S3 Slacks and penalties.gdx',       %List_10_s3slacks%, s2_renNrgPenalty, s2_resvviol ;

  put ss //// '++++ Slack or penalty variables are present in some solutions. Examine'    /
              '     %RepName%.lst and/or "Slacks and penalties.gdx" in the GDX directory' /
              '     for a detailed list of all slack and penalty variables.'              // ;
) ;



*===============================================================================================
* 16. Dump certain parameters into GDX files for use in subsequent programs, e.g. GEMplots and GEMaccess.

Execute_Unload '%OutPath%\%Outprefix%\GDX\%Outprefix% - ReportsData.gdx',
  GEMexecVer, GEMprepoutVer, GEMreportsVer
  activeCapacity, problems, warnings, slacks, numdisyrs, genYr, buildYr, capchrg_r, capchrg_pv, capchrgyr_r, capchrgyr_pv
  taxcred_r, taxcred_pv, fopexgross_r, fopexnet_r, hvdcgross_r, hvdcnet_r, txcapchrgyr_r, txcapchrgyr_pv
  ;




* End of file
