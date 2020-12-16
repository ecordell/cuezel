FROM gcr.io/distroless/base
COPY dyncr /bin/dyncr
EXPOSE 8000
CMD ["/bin/dyncr"]
