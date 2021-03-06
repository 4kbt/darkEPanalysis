function [AMP,ERR] = dispAmpTF(driftFix,frequencies,endCount,dataDivisions,chunkSize,numBETAVal,linearColumn,weighted,displayOut)

  if (nargin != 9)
    usage('[AMP,ERR] = dispAmpTF(driftFix,frequencies,endCount,dataDivisions,chunkSize,numBETAVal,linearColumn,fitIsWeighted,displayOut)');
  endif
  
  dataCut = floor((rows(driftFix))/dataDivisions);

  
  %Accumulation arrays
  %Amplitude at each frequency
  ampFreq = zeros(endCount,numBETAVal);
  %Error of each amplitude value
  ampError = zeros(endCount,numBETAVal);


  %Creates array to collect chunk values for mean/stdev
  valueStuff = zeros(endCount,numBETAVal,dataDivisions);
  
  %Runs the fitter over each bin to find the amplitude at each frequency
  if (weighted) %Performs weighted OLS fit
    for secCount = 0:(dataDivisions-1)
      if (displayOut)
        secCount
      endif
      for count = 1:endCount
        if (displayOut)
          count
          fflush(stdout);
        endif
        designX = createSineComponents(driftFix((secCount*dataCut)+1:(secCount*dataCut)+dataCut,1),frequencies(count));
        if (linearColumn != 0)
          %Prevents linear and constant term from becoming degenerate
          designX(:,linearColumn) = designX(:,linearColumn) .- ((secCount*dataCut)+1);
        endif
        %Fits a data divison with the correct portion of the previously calculated design matrix
        [BETA,COV] = specFreqAmp(driftFix((secCount*dataCut)+1:(secCount*dataCut)+dataCut,:),...
        designX,frequencies(count),chunkSize,linearColumn);
        valueStuff(count,:,secCount + 1) = BETA;
      endfor
    endfor
  else %Performs unweighted OLS fit
    for secCount = 0:(dataDivisions-1)
      secCount
  
      sAmp = ones(endCount,numBETAVal);
  
      for count = 1:endCount
        count
        fflush(stdout);
        designX = createSineComponents(driftFix(((secCount*dataCut)+1:(secCount*dataCut)+dataCut),1),frequencies(count));
        if (linearColumn != 0)
          %Prevents linear and constant term from becoming degenerate
          designX(:,linearColumn) = designX(:,linearColumn) .- ((secCount*dataCut)+1);
        endif
        %Fits without weight the design matrix to the data
        try
          [BETA,SIGMA,R,ERR,COV] = ols2(driftFix((secCount*dataCut)+1:(secCount*dataCut)+dataCut,2),...
          designX);
        catch
          noResonance = [designX(:,1:6),designX(:,9:numBETAVal)];
          [BETA,SIGMA,R,ERR,COV] = ols2(driftFix((secCount*dataCut)+1:(secCount*dataCut)+dataCut,2),...
          noResonance);
        end_try_catch
        valueStuff(count,:,secCount + 1) = BETA;
      endfor
    endfor
  endif
  
  %Sums values over each bin and then averages for the mean
  ampFreq = mean(valueStuff,3);


  %Sums (x-mean(x))^2 and then divides by N-1 takes the sqrt
  ampError = std(valueStuff,0,3); %0 makes std use denominator N-1
  
  %Returns
  AMP = ampFreq;
  ERR = ampError;
endfunction

%!test %Checks that each column is equal to specAmpFreq at that frequency
%! t= 1:10000; t=t';
%! Amp = 1;
%! freq = randn*(1/100);
%! fData = [t,Amp.*sin((2*pi*freq).*t)];
%! startFreq = 1e-3;
%! stopFreq = 1e-2;
%! chunkSize = 50;
%! endCount = floor((stopFreq-startFreq)/(1/rows(t)))+1;
%! dataDivisions = 1;
%! numBETAVal = columns(createSineComponents(1,1));
%! linearColumn = 0;
%!
%! freqArray = ones(endCount,1);
%! for count = 1:endCount
%!   freqArray(count,1) = (startFreq+((count-1)*(1/rows(t))));
%! endfor
%!
%! [ampFreq,ampErr] = dispAmpTF(fData,freqArray,endCount,dataDivisions,chunkSize,...
%! numBETAVal,linearColumn,1,0); %isWeighted = 1; displayOutput = 0
%!
%! compareArray = ones(endCount,numBETAVal);
%! for count = 1:endCount
%!   [BETA,COV] = specFreqAmp(fData,createSineComponents(t,freqArray(count,1)),...
%!   freqArray(count,1),chunkSize,linearColumn);
%!   compareArray(count,:) = BETA;
%! endfor
%! assert(ampFreq,compareArray);

%!test %Checks that mean works
%! t= 1:20000; t=t';
%! Amp = 1;
%! freq = randn*(1/100);
%! fData = [t,Amp.*sin((2*pi*freq).*t)];
%! startFreq = 1e-3;
%! stopFreq = 1e-2;
%! chunkSize = 50;
%! dataDivisions = 2;
%! endCount = floor((stopFreq-startFreq)/(1/rows(t)))+1;
%! numBETAVal = columns(createSineComponents(1,1));
%! linearColumn = numBETAVal - 1;
%!
%! freqArray = ones(endCount,1);
%! for count = 1:endCount
%!   freqArray(count,1) = (startFreq+((count-1)*(1/rows(t))));
%! endfor
%!
%! [ampFreq,ampErr] = dispAmpTF(fData,freqArray,endCount,dataDivisions,chunkSize,...
%! numBETAVal,linearColumn,1,0);%isWeighted = 1; displayOutput = 0
%!
%! compareArray = zeros(endCount,numBETAVal);
%! dataCut = floor((rows(t))/dataDivisions);
%! for secCount = 0:(dataDivisions-1)
%!  for count = 1:endCount
%!    removeConstant = createSineComponents(t((secCount*dataCut)+1:(secCount*dataCut)+dataCut,1),freqArray(count,1));
%!    removeConstant(:,linearColumn) = removeConstant(:,linearColumn) .- ((secCount*dataCut)+1);
%!    [BETA,COV] = specFreqAmp(fData((secCount*dataCut)+1:(secCount*dataCut)+dataCut,:),...
%!    removeConstant,freqArray(count,1),chunkSize,linearColumn);
%!    compareArray(count,:) = compareArray(count,:) + BETA;
%!  endfor
%! endfor
%! compareArray = compareArray ./ dataDivisions;
%! assert(ampFreq,compareArray);