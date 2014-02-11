! HB-Mixture library
!
! Copyright (C) 2014, Piero Gasparotto and Michele Ceriotti
!
! Permission is hereby granted, free of charge, to any person obtaining
! a copy of this software and associated documentation files (the
! "Software"), to deal in the Software without restriction, including
! without limitation the rights to use, copy, modify, merge, publish,
! distribute, sublicense, and/or sell copies of the Software, and to
! permit persons to whom the Software is furnished to do so, subject to
! the following conditions:
!
! The above copyright notice and this permission notice shall be included
! in all copies or substantial portions of the Software.
!
! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
! EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
! MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
! IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
! CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
! TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
! SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
!
! Functions:
!    hbmixture_GetGMMP: Return for each atom sh,sd and sa

      MODULE hbmixture
         USE distance
         USE gaussian
      IMPLICIT NONE

      ! Types used by bitwise operators to control the atom type
      ! they must be power of 2
      INTEGER, PARAMETER :: TYPE_NONE=0
      INTEGER, PARAMETER :: TYPE_H=1
      INTEGER, PARAMETER :: TYPE_DONOR=2
      INTEGER, PARAMETER :: TYPE_ACCEPTOR=4

      CONTAINS

         SUBROUTINE hbmixture_GetGMMP(natoms,cell,icell,alpha,wcutoff,positions, &
                                      masktypes,nk,clusters,pks,sph,spd,spa)
            ! Return for each atoms the sum of the ..
            !
            ! Args:
            !    natoms: The number of atoms in the system.
            !    cell_h: The simulation box cell vector matrix.
            !    cell_ih: The inverse of the simulation box cell vector matrix.
            !    alpha: The smoothing factor
            !    wcutoff: The cutoff in w
            !    positions: The array containing the atoms coordiantes
            !    masktypes: The containing the atoms type
            !    nk: The number of gaussian from gaussian mixture model
            !    clusters: The array containing the structures with the gaussians parameters
            !    pks: The array containing the gaussians Pk
            !    sph:
            !    spd:
            !    spa:
            
            INTEGER, INTENT(IN) :: natoms
            DOUBLE PRECISION, DIMENSION(3,3), INTENT(IN) :: cell
            DOUBLE PRECISION, DIMENSION(3,3), INTENT(IN) :: icell
            DOUBLE PRECISION, INTENT(IN) :: alpha
            DOUBLE PRECISION, INTENT(IN) :: wcutoff
            DOUBLE PRECISION, DIMENSION(3,natoms), INTENT(IN) :: positions
            INTEGER, DIMENSION(natoms), INTENT(IN) :: masktypes
            INTEGER, INTENT(IN) :: nk
            TYPE(gauss_type), DIMENSION(nk), INTENT(IN) :: clusters
            DOUBLE PRECISION, DIMENSION(nk), INTENT(IN) :: pks
            DOUBLE PRECISION, DIMENSION(nk,natoms), INTENT(OUT) :: sph, spa, spd

            DOUBLE PRECISION, DIMENSION(3) :: vwd
            DOUBLE PRECISION, DIMENSION(nk) :: pnk
            DOUBLE PRECISION pnormpk
            INTEGER ih,ia,id,k
            DOUBLE PRECISION rah, rdh

            ! initialize to zero the result vectors
            spa=0.0d0
            spd=0.0d0
            sph=0.0d0
            
            DO ih=1,natoms ! loop over H
               IF (IAND(masktypes(ih),TYPE_H).EQ.0) CYCLE ! test if it is an hydrogen
               DO id=1,natoms ! loop over D
                  ! test if it is a donor
                  IF (IAND(masktypes(id),TYPE_DONOR).EQ.0 .OR. ih.EQ.id) CYCLE
                  ! calculate the D-H distance
                  CALL separation(cell,icell,positions(:,ih),positions(:,id),rdh)
                  IF(rdh .gt. wcutoff) CYCLE  ! if the D-H distance is greater than the cutoff,
                                              ! we can already discard the D-H pair
                  DO ia=1,natoms ! loop over A
                     ! test if it is an acceptor
                     IF (IAND(masktypes(ia),TYPE_ACCEPTOR).EQ.0 &
                         .OR. (ia.EQ.id).OR.(ia.EQ.ih)) CYCLE
                     ! calculate the A-H distance
                     CALL separation(cell,icell,positions(:,ih),positions(:,ia),rah)
                     ! calculate w
                     vwd(2)=rah+rdh
                     IF(vwd(2).GT.wcutoff) CYCLE
                     ! calculate the PTC, v
                     vwd(1)=rdh-rah
                     ! calculate the A-D distance
                     CALL separation(cell,icell,positions(:,id),positions(:,ia),vwd(3))

                     pnk=0.0d0 
                     pnormpk=0.0d0 ! normalization factor (mixture weight)
                     
                     DO k=1,Nk
                        ! calculate the k probability for the point (v,w,rad)
                        ! and apply a smoothing elvating to alpha
                        pnk(k) = (gauss_eval(clusters(k), vwd)*pks(k))**alpha
                        ! calculate the mixture weight
                        pnormpk = pnormpk+pnk(k)
                     ENDDO
                     IF (pnormpk.eq.0.0d0) CYCLE   ! skip cases in which the probability is tooooo tiny
                     pnk = pnk/pnormpk ! normalization
                     
                     sph(:,ih) = sph(:,ih) + pnk(:)
                     spa(:,ia) = spa(:,ia) + pnk(:)
                     spd(:,id) = spd(:,id) + pnk(:)                 
                  ENDDO
               ENDDO
            ENDDO
           

         END SUBROUTINE hbmixture_GetGMMP

      END MODULE hbmixture
