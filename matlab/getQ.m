function Q = getQ(R,T,cr)

for r = 0:R
   for i =1:5
       for l = 1:5
           if (i >= r && l >= r)
               mult = 1;
               for m = 0:r-1
                   mult = mult*(i-m)*(l-m);
               end
               Q(i,l,r+1) = cr(r+1)*2*mult*T^(i+l-2*r + 1)/(i+l-2*r + 1);
           else
               Q(i,l,r+1) = 0;
           end
       end
   end    
end