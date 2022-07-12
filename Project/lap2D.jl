using PyPlot
using Plots
using FFTW
using SparseArrays
using LinearAlgebra
using Images, FileIO

function fft_conv(kernel, n, b, m::ComplexF64)
    # hop = zeros(ComplexF64,size(b)[1],size(b)[2]);
    hop = zeros(ComplexF64,n,n);
    hath = zeros(ComplexF64,size(b)[1],size(b)[2]);
    hop[1:2,1:2] = kernel[2:3,2:3]
    hop[end,1:2] = kernel[1,2:3]
    hop[1:2,end] = kernel[2:3,1]
    hop[end,end] = kernel[1,1]
    hath[1:n,1:n] = fft(hop);
    hatb = fft(b);
    hatu = hatb ./ hath;
    u = ifft(hatu);
    return u;
end

function fft_conv_2(kernel, n, b, m::ComplexF64)
    hop = zeros(ComplexF64,size(b)[1],size(b)[2]);
    hop[1:2,1:2] = kernel[2:3,2:3]
    hop[end,1:2] = kernel[1,2:3]
    hop[1:2,end] = kernel[2:3,1]
    hop[end,end] = kernel[1,1]
    hath = fft(hop);
    hatb = fft(b);
    hatu = hatb ./ hath;
    u = ifft(hatu);
    return u;
end

function fft_conv_3(kernel, n, pad, b, m::ComplexF64)
    # Pad with pad at each side of the grid -> overall (n+2pad)*(n+2pad) grid.
    hop = zeros(ComplexF64,n+2pad,n+2pad);
    hop[1:2,1:2] = kernel[2:3,2:3]
    hop[end,1:2] = kernel[1,2:3]
    hop[1:2,end] = kernel[2:3,1]
    hop[end,end] = kernel[1,1]
    hath = fft(hop);
    b_new = zeros(ComplexF64,n+2pad,n+2pad)
    # b_new[n+1:2n,n+1:2n] .= b
    b_new[Int(pad+1) : Int(pad+n), Int(pad+1) : Int(pad+n)] .= b
    hatb = fft(b_new);
    hatu = hatb ./ hath;
    u = ifft(hatu);
    return u;
end

In = (n::Int64)->(return spdiagm(0=>ones(ComplexF64, n)));

  function matrix_conv(n, h, b, m)
    Lap1D = (h::Float64,n::Int64) -> 
        (A = spdiagm(0=>(2/h^2)*ones(ComplexF64, n),1=>(-1/h^2)*ones(ComplexF64, n-1),-1=>(-1/h^2)*ones(ComplexF64, n-1)); #- Sommerfeld;
        # A[1,end] = -1/h^2;                                # Periodic BC.
        # A[end,1] = -1/h^2;
        A[1,1]=1/h^2;                                       # Neuman BC. See NumericalPDEs to understand why.
        A[1,1] -= 1im * sqrt(real(m)) * (1.0/h);            # Sommerfeld
        A[n,n]=1/h^2;
        A[n,n] -= 1im * sqrt(real(m)) * (1.0/h);            # Sommerfeld
        return A;
        );

    # This is another way to add the Sommerfeld BC. When using this, also uncomment the comment at the end of line 75.
    # fact = 1 * sqrt(real(m)) * (1.0/h);
    # Sommerfeld = zeros(n, n)
    # Sommerfeld[1, :] .= fact
    # Sommerfeld[:, 1] .= fact
    # Sommerfeld[end, :] .= fact
    # Sommerfeld[:, end] .= fact
    # Sommerfeld = 1im .* Sommerfeld
    # Sommerfeld = spdiagm(0=>Sommerfeld[:])
    
    Lap2D = kron(In(n), Lap1D(h,n)) + kron(Lap1D(h,n), In(n)) - m .* spdiagm(0=>ones(ComplexF64, n*n)); #- Sommerfeld;
    b = reshape(b, (n*n, 1))
    return reshape((Lap2D\b),(n,n))
end 


function matrix_conv_without(n, h, b, m)
    Lap1D = (h::Float64,n::Int64) -> 
        (A = spdiagm(0=>(2/h^2)*ones(n),1=>(-1/h^2)*ones(n-1),-1=>(-1/h^2)*ones(n-1));
        # A[1,end] = -1/h^2;            # Periodic BC.
        # A[end,1] = -1/h^2;
        A[1,1]=1/h^2;                   # Neuman BC. See NumericalPDEs to understand why.
        A[n,n]=1/h^2;
        return A;
        );

    Lap2D = kron(In(n), Lap1D(h,n)) + kron(Lap1D(h,n), In(n)) - m .* spdiagm(0=>ones(n*n));
    # print(Lap2D[1, 1])
    b = reshape(b, (n*n, 1))
    return reshape((Lap2D\b),(n,n))
end 

n = 200;
pad = n;
n_pad = n+pad;
h = 2.0/n;
m = (0.1/(h^2))*(1.0 + 1im*0.02)         # m = k^2. In this case it is constant through space (x).
                                        # m is more or less k^2
kernel = zeros(ComplexF64, 3, 3);
kernel += [[0 -1 0];[-1 4 -1];[0 -1 0]] / h^2 - m .* [[0 0 0];[0 1 0];[0 0 0]];
b = zeros(ComplexF64, n, n);
b[div(n,2), div(n,2)] = 1.0;

# Generate G (Green's function for a single source in the middle of the grid).
temp = fft_conv_3(kernel, n, pad, b, m);
heatmap(real.(temp))
g_temp = temp[Int(n/2+1):Int(5n/2),Int(n/2+1):Int(5n/2)]
heatmap(real.(g))

q = zeros(ComplexF64, n, n);
q[div(n,2), div(n,2)] = 1.0;
q_pad = zeros(2n,2n)
q_pad[Int(n/2)+1:Int(3n/2),Int(n/2)+1:Int(3n/2)] .= q

sol = ifft(fft(g) .* fft(q_pad))
sol = sol[Int(n/2)+1:Int(3n/2),Int(n/2)+1:Int(3n/2)]
heatmap(real.(sol))




# Sanity check: L*u needs to return q approximately
Lap1D = (h::Float64,n::Int64) -> 
        (A = spdiagm(0=>(2/h^2)*ones(ComplexF64, n),1=>(-1/h^2)*ones(ComplexF64, n-1),-1=>(-1/h^2)*ones(ComplexF64, n-1)); #- Sommerfeld;
        # A[1,end] = -1/h^2;            # Periodic BC.
        # A[end,1] = -1/h^2;
        A[1,1]=1/h^2;                   # Neuman BC. See NumericalPDEs to understand why.
        A[1,1] -= 1im * sqrt(real(m)) * (1.0/h);
        A[n,n]=1/h^2;
        A[n,n] -= 1im * sqrt(real(m)) * (1.0/h);
        return A;
        );

L = kron(In(n), Lap1D(h,n)) + kron(Lap1D(h,n), In(n)) - m .* spdiagm(0=>ones(n*n));

f = () -> L * vec(sol)

t = f()
t = reshape(t, (n, n))
heatmap(real.(t))
