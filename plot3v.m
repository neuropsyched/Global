function h=plot3v(xyz,cm)
nr=size(xyz,1);
nc=size(xyz,2);
if nargin<2
    cm='b';
end

if nr ~= 3 && nc ~= 3
    error('at least one dimension must be equal to 3');
end

if nc == 3
    h=plot3(xyz(:,1),xyz(:,2),xyz(:,3),cm);
else
    h=plot3(xyz(1,:),xyz(2,:),xyz(3,:),cm);
end

