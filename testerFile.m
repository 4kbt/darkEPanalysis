%%%%%%%%%%%%%%%%%%%% PROBLEM LAYOUT & CONSTANTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Damped oscillator differential equation: x'' + (2wZ) x' + (w^2) x = 0
%Where w is the undamped angular frequency, and Z = 1/2Q. Oscillation is underdamped,
%therefore solution is of the form x = e^(-wZt)[A sin(Ct) + B cos(Ct)]
%C = sqrt[w^2-(wZ)^2] = w*sqrt[1-Z^2]

%torque = kappa*theta + rotI*(d^2 theta/dt^2)

%Pendulum and balance parameters, in SI units:
I = 378/(1e7);                                                                    
f0 = 1.9338e-3;                                                                 
Q = 500000;                                                                     
T = 273+24;  
kappa = (2*pi*f0)^2 * I;

%Latitude, longitude, and compass direction to be input as decimal degrees
  global seattleLat = 47.6593743;
  global seattleLong = -122.30262920000001;
  global compassDir = 90;
  global dipoleMag = 1;

  %Sidereal day frequency
  global omegaEarth = 2*pi*(1/86164.0916);

  %Defining the X vector at January 1st 2000 00:00 UTC
  %Using the website https://www.timeanddate.com/worldclock/sunearth.html
  %At the time Mar 20 2000 07:35 UT
  %80*24*3600 + 7*3600 + 35*60 = 6939300 seconds since January 1, 2000 00:00:00 UTC
  %At the vernal equinox, longitude is equal to zero, so z=0;
  global vernalEqLat = 68.1166667;

  %Prepares seattleLat in terms of equatorial cordinates at January 1, 2000 00:00:00 UTC
  %This is the angle of seattleLat from the X vector
  seattleLat = rad2deg(deg2rad(seattleLat + vernalEqLat)-omegaEarth*6939300);

  
%Variables important to fitting
%How many periods of the specific frequency are included in error fit
chunkSize = 50;
%Multiples of smallest usable frequency between amplitude points
jump = 1;
%Start of frequency scan
startFreq = 1e-3;
%End frequency scan
stopFreq = 1e-2;
%How many points are included in the coherent average bins
dataDivisions = 5;

fullDataCut = floor((fullLength)/dataDivisions);
dataCut = floor((rows(driftFix))/dataDivisions);

%endCount is the #rows of frequency matrix
endCount = floor((stopFreq-startFreq)/(jump*(1/fullDataCut)))
%Creates array to collect values for mean/stdev
valueStuff = zeros(endCount,6*dataDivisions);
%Creates plotting array
ampFreq = zeros(endCount,7);
%Creates error array
ampError = zeros(endCount,7);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Assigns frequency values for the first column of the frequency and error arrays
for i = 1:endCount
  ampFreq(i,1) = (startFreq+((i-1)*jump*(1/fullDataCut)));
endfor
ampError(:,1) = ampFreq(:,1);

i = 1;
%Runs the fitter over each bin to find the amplitude at each frequency
for j=0:(dataCut):((dataDivisions-1)*dataCut)
  j
  fflush(stdout);
  
  %Sums each bin into one array
  sAmp = fakeDarkEPanalysis(driftFix(j+1:(j+dataCut),:),chunkSize,jump,startFreq,endCount,fullLength);
  valueStuff(:,6*i-5:6*i) = sAmp(:,2:7);
  i=i+1;
endfor

%Sums values over each bin and then averages for the mean
for i=1:dataDivisions
  ampFreq(:,2:7) = ampFreq(:,2:7) + valueStuff(:,6*i-5:6*i);
endfor
ampFreq(:,2:7) = ampFreq(:,2:7)./dataDivisions;

%Sums (x-mean(x))^2 and then divides by N-1 takes the sqrt
for j=1:dataDivisions
  ampError(:,2:7) = ampError(:,2:7) + (valueStuff(:,6*i-5:6*i).-ampFreq(:,2:7)).^2;
endfor
ampError(:,2:7) = sqrt(ampError(:,2:7)./(dataDivisions-1));


%Initializes the response function for each frequency of the amplitudes
tau = transferFunction(ampFreq(:,1),kappa,f0,Q);

%Creates array for final data
FINALAMP = ones(rows(ampFreq),5);
FINALERR = ones(rows(ampError),5);
for count = 1:rows(ampFreq)
%Sums in quadrature the averaged sine/cosine amplitudes (inner product)
FINALAMP(count,:) = [ampFreq(count,1),abs(sqrt(ampFreq(count,[3,5])*ampFreq(count,[3,5])')/tau(ampFreq(count,1))),...
abs(sqrt(ampFreq(count,[2,4])*ampFreq(count,[2,4])')/transferFunction(ampFreq(count,1),kappa,f0,Q)),...
abs(sqrt(ampFreq(count,6:7)*ampFreq(count,6:7)')/transferFunction(ampFreq(count,1),kappa,f0,Q)),...
abs(sqrt(ampFreq(count,2:7)*ampFreq(count,2:7)')/transferFunction(ampFreq(count,1),kappa,f0,Q))];

FINALERR(count,2) = abs(sqrt(((ampFreq(count,3)^2)./(ampFreq(count,3)^2+ampFreq(count,5)^2))*ampError(count,3)^2 ...
+((ampFreq(count,5)^2)./(ampFreq(count,3)^2+ampFreq(count,5)^2))*ampError(count,5)^2)/transferFunction(ampFreq(count,1),kappa,f0,Q)); 
FINALERR(count,3) = abs(sqrt(((ampFreq(count,2)^2)./(ampFreq(count,2)^2+ampFreq(count,4)^2))*ampError(count,2)^2 ...
+((ampFreq(count,4)^2)./(ampFreq(count,2)^2+ampFreq(count,4)^2))*ampError(count,4)^2)/transferFunction(ampFreq(count,1),kappa,f0,Q));
FINALERR(count,4) = abs(sqrt(((ampFreq(count,6)^2)./(ampFreq(count,6)^2+ampFreq(count,7)^2))*ampError(count,6)^2 ...
+((ampFreq(count,7)^2)./(ampFreq(count,6)^2+ampFreq(count,7)^2))*ampError(count,7)^2)/transferFunction(ampFreq(count,1),kappa,f0,Q));
endfor

FINALERR(:,1) = FINALAMP(:,1);

%Plots torque power as a function of frequency
figure(1);
loglogerr(FINALAMP(:,1),FINALAMP(:,2),FINALERR(:,2));
xlabel('Frequency (Hz)');
ylabel('Torque (N m)');
title('Torque vs frequency parallel to gamma');

figure(2);
loglogerr(FINALAMP(:,1),FINALAMP(:,3),FINALERR(:,3));
xlabel('Frequency (Hz)');
ylabel('Torque (N m)');
title('Torque vs frequency perpendicular to gamma');

figure(3);
loglogerr(FINALAMP(:,1),FINALAMP(:,4),FINALERR(:,4));
xlabel('Frequency (Hz)');
ylabel('Torque (N m)');
title('Torque vs frequency in the z component');

figure(4);
loglog(FINALAMP(:,1),FINALAMP(:,2),FINALAMP(:,1),FINALAMP(:,3),FINALAMP(:,1),FINALAMP(:,4),FINALAMP(:,1),FINALAMP(:,5));
legend('Parallel to gamma','Perpendicular to gamma','Z component','Sum signal');
xlabel('Frequency (Hz)');
ylabel('Torque (N m)');
title('Torque vs frequency');


%Index of specific frequency:
%i = floor((freq - startFreq)*dataCut + 1)