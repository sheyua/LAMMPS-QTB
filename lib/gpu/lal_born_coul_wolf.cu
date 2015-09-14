// **************************************************************************
//                              born_coul_wolf.cu
//                             -------------------
//                           Trung Dac Nguyen (ORNL)
//
//  Device code for acceleration of the born/coul/wolf pair style
//
// __________________________________________________________________________
//    This file is part of the LAMMPS Accelerator Library (LAMMPS_AL)
// __________________________________________________________________________
//
//    begin                : 
//    email                : nguyentd@ornl.gov
// ***************************************************************************/

#ifdef NV_KERNEL

#include "lal_aux_fun1.h"
#ifndef _DOUBLE_DOUBLE
texture<float4> pos_tex;
texture<float> q_tex;
#else
texture<int4,1> pos_tex;
texture<int2> q_tex;
#endif

#else
#define pos_tex x_
#define q_tex q_
#endif

#define MY_PIS (acctyp)1.77245385090551602729

__kernel void k_born_wolf(const __global numtyp4 *restrict x_, 
                          const __global numtyp4 *restrict coeff1,
                          const __global numtyp4 *restrict coeff2, 
                          const int lj_types, 
                          const __global numtyp *restrict sp_lj_in, 
                          const __global int *dev_nbor, 
                          const __global int *dev_packed, 
                          __global acctyp4 *restrict ans,
                          __global acctyp *restrict engv, 
                          const int eflag, const int vflag, const int inum,
                          const int nbor_pitch, 
                          const __global numtyp *restrict q_,
                          const __global numtyp4 *restrict cutsq_sigma, 
                          const numtyp cut_coulsq, const numtyp qqrd2e,
                          const numtyp alf, const numtyp e_shift, 
                          const numtyp f_shift, const int t_per_atom) {
  int tid, ii, offset;
  atom_info(t_per_atom,ii,tid,offset);

  __local numtyp sp_lj[8];
  sp_lj[0]=sp_lj_in[0];
  sp_lj[1]=sp_lj_in[1];
  sp_lj[2]=sp_lj_in[2];
  sp_lj[3]=sp_lj_in[3];
  sp_lj[4]=sp_lj_in[4];
  sp_lj[5]=sp_lj_in[5];
  sp_lj[6]=sp_lj_in[6];
  sp_lj[7]=sp_lj_in[7];

  acctyp energy=(acctyp)0;
  acctyp e_coul=(acctyp)0;
  acctyp4 f;
  f.x=(acctyp)0; f.y=(acctyp)0; f.z=(acctyp)0;
  acctyp virial[6];
  for (int i=0; i<6; i++)
    virial[i]=(acctyp)0;
  
  if (ii<inum) {
    int nbor, nbor_end;
    int i, numj;
    __local int n_stride;
    nbor_info(dev_nbor,dev_packed,nbor_pitch,t_per_atom,ii,offset,i,numj,
              n_stride,nbor_end,nbor);
  
    numtyp4 ix; fetch4(ix,i,pos_tex); //x_[i];
    numtyp qtmp; fetch(qtmp,i,q_tex);
    int itype=ix.w;

    if (eflag>0) {
      acctyp e_self = -((acctyp)0.5*e_shift + alf/MY_PIS) * 
        qtmp*qtmp*qqrd2e/(acctyp)t_per_atom;
      e_coul += (acctyp)2.0*e_self;
    }

    for ( ; nbor<nbor_end; nbor+=n_stride) {
      int j=dev_packed[nbor];

      numtyp factor_lj, factor_coul;
      factor_lj = sp_lj[sbmask(j)];
      factor_coul = sp_lj[sbmask(j)+4];
      j &= NEIGHMASK;

      numtyp4 jx; fetch4(jx,j,pos_tex); //x_[j];
      int jtype=jx.w;

      // Compute r12
      numtyp delx = ix.x-jx.x;
      numtyp dely = ix.y-jx.y;
      numtyp delz = ix.z-jx.z;
      numtyp rsq = delx*delx+dely*dely+delz*delz;

      int mtype=itype*lj_types+jtype;
      if (rsq<cutsq_sigma[mtype].x) { // cutsq
        numtyp r2inv = ucl_recip(rsq);
        numtyp forcecoul, forceborn, force, r6inv, prefactor;
        numtyp v_sh = (numtyp)0.0;
        numtyp rexp = (numtyp)0.0;
        
        if (rsq < cutsq_sigma[mtype].y) { // cut_ljsq
          numtyp r = ucl_sqrt(rsq);
          rexp = ucl_exp((cutsq_sigma[mtype].z-r)*coeff1[mtype].x);
          r6inv = r2inv*r2inv*r2inv;
          forceborn = (coeff1[mtype].y*r*rexp - coeff1[mtype].z*r6inv 
            + coeff1[mtype].w*r2inv*r6inv)*factor_lj;
        } else forceborn = (numtyp)0.0;

        if (rsq < cut_coulsq) {
          numtyp r=ucl_rsqrt(r2inv);
          numtyp arij = alf * r;
          numtyp erfcd = ucl_exp(-arij*arij);
          fetch(prefactor,j,q_tex);
          prefactor *= qqrd2e * qtmp/r;

          const numtyp erfcc = erfc(arij);
          v_sh = (erfcc - e_shift*r)*prefactor;
          numtyp dvdrr = (erfcc/rsq + (numtyp)2.0*alf/MY_PIS * erfcd/r) + f_shift;
          forcecoul = prefactor * dvdrr*rsq;
          if (factor_coul < (numtyp)1.0) forcecoul -= ((numtyp)1.0-factor_coul)*prefactor;
        } else forcecoul = (numtyp)0.0;

        force = (forceborn + forcecoul) * r2inv;

        f.x+=delx*force;
        f.y+=dely*force;
        f.z+=delz*force;

        if (eflag>0) {
          if (rsq < cut_coulsq) {
            numtyp e=v_sh;
            if (factor_coul < (numtyp)1.0) e -= ((numtyp)1.0-factor_coul)*prefactor;
            e_coul += e;
          }
          if (rsq < cutsq_sigma[mtype].y) {
            numtyp e=coeff2[mtype].x*rexp - coeff2[mtype].y*r6inv
              + coeff2[mtype].z*r2inv*r6inv;
            energy+=factor_lj*(e-coeff2[mtype].w);
          } 
        }
        if (vflag>0) {
          virial[0] += delx*delx*force;
          virial[1] += dely*dely*force;
          virial[2] += delz*delz*force;
          virial[3] += delx*dely*force;
          virial[4] += delx*delz*force;
          virial[5] += dely*delz*force;
        }
      }

    } // for nbor
    store_answers_q(f,energy,e_coul,virial,ii,inum,tid,t_per_atom,offset,eflag,
                    vflag,ans,engv);
  } // if ii
}

__kernel void k_born_wolf_fast(const __global numtyp4 *restrict x_, 
                               const __global numtyp4 *restrict coeff1_in,
                               const __global numtyp4 *restrict coeff2_in, 
                               const __global numtyp *restrict sp_lj_in,
                               const __global int *dev_nbor, 
                               const __global int *dev_packed,
                               __global acctyp4 *restrict ans, 
                               __global acctyp *restrict engv, 
                               const int eflag, const int vflag, const int inum, 
                               const int nbor_pitch, 
                               const __global numtyp *restrict q_,
                               const __global numtyp4 *restrict cutsq_sigma,
                               const numtyp cut_coulsq, const numtyp qqrd2e,
                               const numtyp alf, const numtyp e_shift, 
                               const numtyp f_shift, const int t_per_atom) {
  int tid, ii, offset;
  atom_info(t_per_atom,ii,tid,offset);

  __local numtyp4 coeff1[MAX_SHARED_TYPES*MAX_SHARED_TYPES];
  __local numtyp4 coeff2[MAX_SHARED_TYPES*MAX_SHARED_TYPES];
  __local numtyp sp_lj[8];
  if (tid<8)
    sp_lj[tid]=sp_lj_in[tid];
  if (tid<MAX_SHARED_TYPES*MAX_SHARED_TYPES) {
    coeff1[tid]=coeff1_in[tid];
    if (eflag>0)
      coeff2[tid]=coeff2_in[tid];
  }
  
  acctyp energy=(acctyp)0;
  acctyp e_coul=(acctyp)0;
  acctyp4 f;
  f.x=(acctyp)0; f.y=(acctyp)0; f.z=(acctyp)0;
  acctyp virial[6];
  for (int i=0; i<6; i++)
    virial[i]=(acctyp)0;
  
  __syncthreads();
  
  if (ii<inum) {
    int nbor, nbor_end;
    int i, numj;
    __local int n_stride;
    nbor_info(dev_nbor,dev_packed,nbor_pitch,t_per_atom,ii,offset,i,numj,
              n_stride,nbor_end,nbor);
  
    numtyp4 ix; fetch4(ix,i,pos_tex); //x_[i];
    numtyp qtmp; fetch(qtmp,i,q_tex);
    int iw=ix.w;
    int itype=fast_mul((int)MAX_SHARED_TYPES,iw);

    if (eflag>0) {
      acctyp e_self = -((acctyp)0.5*e_shift + alf/MY_PIS) * 
        qtmp*qtmp*qqrd2e/(acctyp)t_per_atom;
      e_coul += (acctyp)2.0*e_self;
    }

    for ( ; nbor<nbor_end; nbor+=n_stride) {
      int j=dev_packed[nbor];

      numtyp factor_lj, factor_coul;
      factor_lj = sp_lj[sbmask(j)];
      factor_coul = sp_lj[sbmask(j)+4];
      j &= NEIGHMASK;

      numtyp4 jx; fetch4(jx,j,pos_tex); //x_[j];
      int mtype=itype+jx.w;

      // Compute r12
      numtyp delx = ix.x-jx.x;
      numtyp dely = ix.y-jx.y;
      numtyp delz = ix.z-jx.z;
      numtyp rsq = delx*delx+dely*dely+delz*delz;

      if (rsq<cutsq_sigma[mtype].x) {
        numtyp r2inv=ucl_recip(rsq);
        numtyp forcecoul, forceborn, force, r6inv, prefactor;
        numtyp v_sh = (numtyp)0.0;
        numtyp rexp = (numtyp)0.0;
        
        if (rsq < cutsq_sigma[mtype].y) {
          numtyp r = ucl_sqrt(rsq);
          rexp = ucl_exp((cutsq_sigma[mtype].z-r)*coeff1[mtype].x);
          r6inv = r2inv*r2inv*r2inv;
          forceborn = (coeff1[mtype].y*r*rexp - coeff1[mtype].z*r6inv 
            + coeff1[mtype].w*r2inv*r6inv)*factor_lj;
        } else forceborn = (numtyp)0.0;

        if (rsq < cut_coulsq) {
          numtyp r=ucl_sqrt(rsq);
          numtyp arij = alf * r;
          numtyp erfcd = ucl_exp(-arij*arij);
          fetch(prefactor,j,q_tex);
          prefactor *= qqrd2e * qtmp/r;

          const numtyp erfcc = erfc(arij);
          v_sh = (erfcc - e_shift*r)*prefactor;
          numtyp dvdrr = (erfcc/rsq + (numtyp)2.0*alf/MY_PIS * erfcd/r) + f_shift;
          forcecoul = prefactor * dvdrr*rsq;
          if (factor_coul < (numtyp)1.0) forcecoul -= ((numtyp)1.0-factor_coul)*prefactor;
        } else forcecoul = (numtyp)0.0;

        force = (forceborn + forcecoul) * r2inv;

        f.x+=delx*force;
        f.y+=dely*force;
        f.z+=delz*force;

        if (eflag>0) {
          if (rsq < cut_coulsq) {
            numtyp e=v_sh;
            if (factor_coul < (numtyp)1.0) e -= ((numtyp)1.0-factor_coul)*prefactor;
            e_coul += e;
          }
          if (rsq < cutsq_sigma[mtype].y) {
            numtyp e=coeff2[mtype].x*rexp - coeff2[mtype].y*r6inv
              + coeff2[mtype].z*r2inv*r6inv;
            energy+=factor_lj*(e-coeff2[mtype].w);
          }
        }
        if (vflag>0) {
          virial[0] += delx*delx*force;
          virial[1] += dely*dely*force;
          virial[2] += delz*delz*force;
          virial[3] += delx*dely*force;
          virial[4] += delx*delz*force;
          virial[5] += dely*delz*force;
        }
      }

    } // for nbor
    store_answers_q(f,energy,e_coul,virial,ii,inum,tid,t_per_atom,offset,eflag,
                    vflag,ans,engv);
  } // if ii
}
