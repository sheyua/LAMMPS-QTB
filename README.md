This repository contains the Quantum Thermal Bath (QTB) package which enables
quantum nuclear effects in Molecular Dynamics simulations and the Large-scale
Atomic/Molecular Massively Parallel Simulator (LAMMPS) code on top of it.

The QTB package has source code located in src/USER-QTB. Please include this 
package with the following commands while compiling LAMMPS.

	cd src
	make yes-USER-QTB
	make openmpi // or any other make version depending on your machine

/***********************************************************************************************
* LAMMPS README
***********************************************************************************************/

This is the LAMMPS software package.

LAMMPS stands for Large-scale Atomic/Molecular Massively Parallel
Simulator.

Copyright (2003) Sandia Corporation.  Under the terms of Contract
DE-AC04-94AL85000 with Sandia Corporation, the U.S. Government retains
certain rights in this software.  This software is distributed under
the GNU General Public License.

LAMMPS is a classical molecular dynamics simulation code designed to
run efficiently on parallel computers.  It was developed at Sandia
National Laboratories, a US Department of Energy facility, with
funding from the DOE.  It is an open-source code, distributed freely
under the terms of the GNU Public License (GPL).

The primary author of the code is Steve Plimpton, who can be emailed
at sjplimp@sandia.gov.  The LAMMPS WWW Site at lammps.sandia.gov has
more information about the code and its uses.

The LAMMPS distribution includes the following files and directories:

README			   this file
LICENSE			   the GNU General Public License (GPL)
bench			   benchmark problems
couple			   code coupling examples using LAMMPS as a library
doc			   documentation
examples		   simple test problems
lib			   libraries LAMMPS can be linked with
potentials		   interatomic potential files
python			   Python wrapper on LAMMPS as a library
src			   source files
tools			   pre- and post-processing tools

Point your browser at any of these files to get started:

doc/Manual.html	           the LAMMPS manual
doc/Section_intro.html	   hi-level introduction to LAMMPS
doc/Section_start.html	   how to build and use LAMMPS
doc/Developer.pdf          LAMMPS developer guide

/***********************************************************************************************
* QTB README
***********************************************************************************************/

This package contains 2 fix commands, "fix qtb" and 
"fix qbmsst" which involves quantum nuclear effects.

What is quantum nuclear effects (in molecular dynamics 
simulation)?

	Quantum treatment of the vibrational modes will 
	introduce zero point energy into the system, alter 
	the energy power spectrum and bias the heat capacity 
	from the classical limit. classical MD leaves out 
	these effects completely and thus need to be corrected.
	
When should I consider quantum nuclear effects in 
my simulation?

	(1) When you want to model systems at temperatures 
	lower than their classical limits. This is especially 
	important for materials with a large population of 
	hydrogen atoms and thus higher classical limits.

	(2) In MD simulations when temperatures ramp up 
	across (or starting from somewhere close to) the 
	classical limits, tiny differences between the 
	classical and quantum heat capacity can accumulate 
	and cause the final state to deviate (could be as 
	large as 30 %).

What command should I use regarding these two cases?

	(1) "fix qtb" provides quantum nulcear correction 
	through a colored thermostat and can be used with 
	other time integration schemes like fix nve or 
	fix nph. In this case, you tell "fix qtb" the temperature 
	and the other time integration scheme either the 
	pressure ("fix nph") or the volume ("fix nve").

	(2) "fix qbmsst" deals with shock MD simulations 
	in which cases the temperature may increase a lot. 
	It enables quantum nuclear correction of a multi-scale 
	shock technique simulation by coupling the quantum 
	thermal bath with the shocked system. It is an independent 
	command from "fix msst" and does not assume that 
	the SHOCK package has been installed.

	See the doc page for the fix qtb and fix qbmsst 
	command for detailed usage instructions.

Where can I find examples of these two commands?

	There are example scripts for using this package in
	examples/USER/qtb, including one "fix qtb" and one 
	"fix qbmsst" example for each of alpha quartz and 
	methane. Running the alpha quartz example requires 
	installation of the kspace package while the methane 
	example requires the REAX package for the force field. 

Authors Information and Contact

	The person who created this package is Yuan Shen 
	(sy0302 at stanford.edu) at Stanford University. 
	Contact him directly if you have questions.
